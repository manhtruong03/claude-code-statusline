// RED phase tests — these must FAIL before fixes are applied
// Run: node --test test/parse.test.js

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const { parseFields } = require("./helpers/parse");

const EPOCH_7PM = 1713567600;   // 2024-04-19 19:00:00 UTC — simulates "7:00pm"
const EPOCH_APR24 = 1713920400; // 2024-04-24 03:00:00 UTC — simulates "apr 24, 3:00am"

function makePayload(overrides = {}) {
  return {
    model: { display_name: "Claude Sonnet 4" },
    context_window: {
      context_window_size: 200000,
      used_percentage: 27,
      current_usage: {
        input_tokens: 8000,
        cache_read_input_tokens: 47000,
        cache_creation_input_tokens: 6000,
        output_tokens: 1000,
      },
    },
    workspace: { current_dir: "/home/user/backend" },
    cost: { total_duration_ms: 180000 },
    session_id: "abc123",
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Effort level — Bug 1: numeric values & new levels
// ---------------------------------------------------------------------------
describe("effort level display", () => {
  const effortCases = [
    // Claude Code numeric format
    { input: "1", label: "",   desc: "1 (none) → hidden" },
    { input: "2", label: "L",  desc: "2 (low) → L" },
    { input: "3", label: "Md", desc: "3 (medium) → Md (not M, to distinguish from Max)" },
    { input: "4", label: "H",  desc: "4 (high) → H" },
    { input: "5", label: "XH", desc: "5 (xhigh) → XH" },
    { input: "6", label: "Mx", desc: "6 (max) → Mx (not M, to distinguish from Medium)" },
    // Text format (backwards compatibility)
    { input: "none",   label: "",   desc: "text none → hidden" },
    { input: "low",    label: "L",  desc: "text low → L" },
    { input: "medium", label: "Md", desc: "text medium → Md" },
    { input: "high",   label: "H",  desc: "text high → H" },
    { input: "xhigh",  label: "XH", desc: "text xhigh → XH" },
    { input: "max",    label: "Mx", desc: "text max → Mx" },
    // Unknown / empty
    { input: "",       label: "",   desc: "empty → hidden" },
  ];

  for (const { input, label, desc } of effortCases) {
    test(desc, () => {
      const fields = parseFields(
        JSON.stringify(makePayload()),
        input
      );
      assert.equal(fields.effortLabel, label);
    });
  }
});

// ---------------------------------------------------------------------------
// Rate limits — Bug 2: field order (pct before reset time)
// ---------------------------------------------------------------------------
describe("rate limits field order", () => {
  test("five_hour pct at index 15, reset at index 16", () => {
    const payload = makePayload({
      rate_limits: {
        five_hour: { used_percentage: 62, resets_at: EPOCH_7PM },
        seven_day: {},
      },
    });
    const fields = parseFields(JSON.stringify(payload), "");
    // index 15 must be the numeric percentage string
    assert.match(fields.raw[15], /^\d+$/, "fields[15] should be the percentage number");
    // index 16 must be the human-readable time string
    assert.match(fields.raw[16], /\d+:\d+/, "fields[16] should contain a time (H:MM)");
  });

  test("seven_day pct at index 17, reset at index 18", () => {
    const payload = makePayload({
      rate_limits: {
        five_hour: {},
        seven_day: { used_percentage: 38, resets_at: EPOCH_APR24 },
      },
    });
    const fields = parseFields(JSON.stringify(payload), "");
    assert.match(fields.raw[17], /^\d+$/, "fields[17] should be the weekly percentage");
    assert.match(fields.raw[18], /\d+:\d+/, "fields[18] should contain a time");
  });

  test("five_hour percentage value is correct", () => {
    const payload = makePayload({
      rate_limits: {
        five_hour: { used_percentage: 62, resets_at: EPOCH_7PM },
      },
    });
    const fields = parseFields(JSON.stringify(payload), "");
    assert.equal(fields.raw[15], "62");
  });

  test("empty rate_limits gives empty rl fields", () => {
    const payload = makePayload({ rate_limits: {} });
    const fields = parseFields(JSON.stringify(payload), "");
    assert.equal(fields.raw[15], "");
    assert.equal(fields.raw[16], "");
    assert.equal(fields.raw[17], "");
    assert.equal(fields.raw[18], "");
  });
});
