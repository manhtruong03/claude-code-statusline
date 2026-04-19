// E2E tests — pipes JSON directly into statusline.sh and asserts on stdout.
// Run: node --test test/e2e.test.js
//
// These will FAIL (RED) until statusline.sh is fixed.

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const { execSync, spawnSync } = require("node:child_process");
const path = require("node:path");
const fs = require("node:fs");
const os = require("node:os");

const SCRIPT = path.join(__dirname, "..", "statusline.sh");

const EPOCH_7PM = 1713567600;   // 2024-04-19 19:00:00 UTC
const EPOCH_APR24 = 1713920400; // 2024-04-24 03:00:00 UTC

function run(json, env = {}) {
  const result = spawnSync("bash", [SCRIPT], {
    input: JSON.stringify(json),
    encoding: "utf8",
    // On Windows Node.js uses USERPROFILE for os.homedir(), not HOME.
    env: { ...process.env, ...env, ...(env.HOME ? { USERPROFILE: env.HOME } : {}) },
    timeout: 5000,
  });
  if (result.error) throw result.error;
  // Strip ANSI codes for easier assertion
  const clean = result.stdout.replace(/\x1b\[[0-9;]*m/g, "").replace(/\r/g, "");
  return clean.split("\n").filter(Boolean);
}

function basePayload(overrides = {}) {
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
    session_id: "testsession",
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Effort — Bug 1
// ---------------------------------------------------------------------------
describe("E2E: effort level display on Line 1", () => {
  test("numeric 4 renders as H (not the digit 4)", () => {
    // The script reads effort from ~/.claude/settings.json.
    // We temporarily write a test settings.json to a temp path and set
    // HOME to point to a temp dir, so the script reads a known value.
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    fs.writeFileSync(
      path.join(claudeDir, "settings.json"),
      JSON.stringify({ env: { CLAUDE_CODE_EFFORT_LEVEL: "4" } })
    );
    const lines = run(basePayload(), { HOME: tmpDir });
    fs.rmSync(tmpDir, { recursive: true });
    const line1 = lines[0];
    assert.ok(!line1.includes("🧠4"), `Line 1 should not show digit "4": ${line1}`);
    assert.ok(line1.includes("🧠H") || line1.includes("[E]H"), `Line 1 should show "H": ${line1}`);
  });

  test("xhigh on Opus renders as XH", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    fs.writeFileSync(
      path.join(claudeDir, "settings.json"),
      JSON.stringify({ env: { CLAUDE_CODE_EFFORT_LEVEL: "xhigh" } })
    );
    const lines = run(
      { ...basePayload(), model: { display_name: "Claude Opus 4" } },
      { HOME: tmpDir }
    );
    fs.rmSync(tmpDir, { recursive: true });
    assert.ok(lines[0].includes("XH"), `Opus+xhigh should show XH: ${lines[0]}`);
  });

  test("xhigh on Sonnet renders as Mx (no xhigh level on Sonnet)", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    fs.writeFileSync(
      path.join(claudeDir, "settings.json"),
      JSON.stringify({ env: { CLAUDE_CODE_EFFORT_LEVEL: "xhigh" } })
    );
    const lines = run(
      { ...basePayload(), model: { display_name: "Claude Sonnet 4" } },
      { HOME: tmpDir }
    );
    fs.rmSync(tmpDir, { recursive: true });
    assert.ok(lines[0].includes("Mx"), `Sonnet+xhigh should show Mx: ${lines[0]}`);
  });

  test("text 'medium' renders as Md (not M, to avoid confusion with Max)", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    fs.writeFileSync(
      path.join(claudeDir, "settings.json"),
      JSON.stringify({ env: { CLAUDE_CODE_EFFORT_LEVEL: "medium" } })
    );
    const lines = run(basePayload(), { HOME: tmpDir });
    fs.rmSync(tmpDir, { recursive: true });
    const line1 = lines[0];
    assert.ok(line1.includes("Md"), `Line 1 should show "Md" for medium: ${line1}`);
    // Must not show bare "M" which would be ambiguous with Max
    // Check the badge portion only (bounded by "[" and "]")
    const badge = line1.match(/\[.*?\]/)?.[0] || "";
    assert.ok(!badge.match(/·M[^d]/), `Badge should not show bare "·M" in: ${badge}`);
  });

  test("xhigh on non-Opus model (Sonnet/Haiku) renders as Mx not XH", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    fs.writeFileSync(
      path.join(claudeDir, "settings.json"),
      JSON.stringify({ effortLevel: "xhigh" })
    );
    // Sonnet model — xhigh should collapse to max
    const lines = run(
      { ...basePayload(), model: { display_name: "Claude Sonnet 4" } },
      { HOME: tmpDir }
    );
    fs.rmSync(tmpDir, { recursive: true });
    assert.ok(lines[0].includes("Mx"), `Sonnet+xhigh should show Mx: ${lines[0]}`);
    assert.ok(!lines[0].includes("XH"), `Sonnet+xhigh must not show XH: ${lines[0]}`);
  });

  test("xhigh on Opus model renders as XH", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    fs.writeFileSync(
      path.join(claudeDir, "settings.json"),
      JSON.stringify({ effortLevel: "xhigh" })
    );
    // Opus model — xhigh is valid, must show XH
    const lines = run(
      { ...basePayload(), model: { display_name: "Claude Opus 4" } },
      { HOME: tmpDir }
    );
    fs.rmSync(tmpDir, { recursive: true });
    assert.ok(lines[0].includes("XH"), `Opus+xhigh should show XH: ${lines[0]}`);
  });

  test("effortLevel top-level key (current Claude Code format) is read correctly", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    // Current Claude Code stores effort as top-level "effortLevel", not inside "env"
    fs.writeFileSync(
      path.join(claudeDir, "settings.json"),
      JSON.stringify({ effortLevel: "xhigh" })
    );
    const lines = run(
      { ...basePayload(), model: { display_name: "Claude Opus 4" } },
      { HOME: tmpDir }
    );
    fs.rmSync(tmpDir, { recursive: true });
    assert.ok(lines[0].includes("XH"), `Should read effortLevel top-level key on Opus: ${lines[0]}`);
  });

  test("text 'max' renders as Mx (not M)", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    fs.writeFileSync(
      path.join(claudeDir, "settings.json"),
      JSON.stringify({ env: { CLAUDE_CODE_EFFORT_LEVEL: "max" } })
    );
    const lines = run(basePayload(), { HOME: tmpDir });
    fs.rmSync(tmpDir, { recursive: true });
    const line1 = lines[0];
    assert.ok(line1.includes("Mx"), `Line 1 should show "Mx" for max: ${line1}`);
  });
});

// ---------------------------------------------------------------------------
// Rate limits — Bug 2
// ---------------------------------------------------------------------------
describe("E2E: rate limits on Line 3", () => {
  test("percentage appears before reset time in Line 3", () => {
    const payload = basePayload({
      rate_limits: {
        five_hour: { used_percentage: 62, resets_at: EPOCH_7PM },
        seven_day: { used_percentage: 38, resets_at: EPOCH_APR24 },
      },
    });
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    fs.writeFileSync(path.join(claudeDir, "settings.json"), "{}");
    const lines = run(payload, { HOME: tmpDir });
    fs.rmSync(tmpDir, { recursive: true });

    const line3 = lines[2] || "";
    // "current 62% ↻ 7:..." — percentage must come before the ↻ arrow
    const currentMatch = line3.match(/current\s+(\S+?)%\s+↻\s+(.+?)(?:\s+\||\s*$)/);
    assert.ok(currentMatch, `Line 3 must match "current N% ↻ time" pattern: "${line3}"`);
    assert.match(currentMatch[1], /^\d+$/, `Percentage part must be a number, got: "${currentMatch[1]}"`);
    assert.match(currentMatch[2], /\d+:\d+/, `Reset part must contain a time, got: "${currentMatch[2]}"`);
  });

  test("weekly percentage appears before weekly reset time", () => {
    const payload = basePayload({
      rate_limits: {
        five_hour: { used_percentage: 62, resets_at: EPOCH_7PM },
        seven_day: { used_percentage: 38, resets_at: EPOCH_APR24 },
      },
    });
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    fs.writeFileSync(path.join(claudeDir, "settings.json"), "{}");
    const lines = run(payload, { HOME: tmpDir });
    fs.rmSync(tmpDir, { recursive: true });

    const line3 = lines[2] || "";
    const weeklyMatch = line3.match(/weekly\s+(\S+?)%\s+↻\s+(.+)$/);
    assert.ok(weeklyMatch, `Line 3 must contain "weekly N% ↻ time": "${line3}"`);
    assert.match(weeklyMatch[1], /^\d+$/, `Weekly percentage must be a number, got: "${weeklyMatch[1]}"`);
    assert.match(weeklyMatch[2], /\d+:\d+/, `Weekly reset must contain a time, got: "${weeklyMatch[2]}"`);
  });

  test("Line 3 absent when rate_limits not present", () => {
    const payload = basePayload();
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "cc-test-"));
    const claudeDir = path.join(tmpDir, ".claude");
    fs.mkdirSync(claudeDir);
    fs.writeFileSync(path.join(claudeDir, "settings.json"), "{}");
    const lines = run(payload, { HOME: tmpDir });
    fs.rmSync(tmpDir, { recursive: true });
    assert.equal(lines.length, 2, `Should have only 2 lines when no rate limits, got: ${lines.length}`);
  });
});
