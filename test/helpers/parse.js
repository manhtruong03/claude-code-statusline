// Test harness — runs the Node.js parsing logic extracted from statusline.sh.
// This mirrors the inline `node -e '...'` block so we can unit-test it without
// spawning bash.

const fs = require("fs");
const os = require("os");

function fmtReset(epoch) {
  if (!epoch) return "";
  const d = new Date(epoch * 1000);
  const now = new Date();
  const sameDay = d.toDateString() === now.toDateString();
  const time = d
    .toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", hour12: true })
    .toLowerCase()
    .replace(/\s+/g, "");
  if (sameDay) return time;
  const md = d
    .toLocaleDateString("en-US", { month: "short", day: "numeric" })
    .toLowerCase();
  return md + ", " + time;
}

function humanize(n) {
  if (n >= 1000000) return (n / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
  if (n >= 1000) return Math.round(n / 1000) + "k";
  return String(n);
}

// Map numeric or text effort to canonical text label used by bash.
// Numeric scale: 1=none, 2=low, 3=medium, 4=high, 5=xhigh, 6=max
const EFFORT_CANONICAL = {
  "1": "none", "2": "low", "3": "medium", "4": "high", "5": "xhigh", "6": "max",
};

function canonicalEffort(raw) {
  if (!raw) return "";
  return EFFORT_CANONICAL[String(raw)] || String(raw).toLowerCase();
}

// Map canonical effort text to display label (avoids M ambiguity for medium/max).
const EFFORT_LABEL = {
  none: "",
  low: "L",
  medium: "Md",
  high: "H",
  xhigh: "XH",
  max: "Mx",
};

function effortLabel(canonical) {
  if (!canonical) return "";
  return EFFORT_LABEL[canonical] ?? "";
}

/**
 * Parse a Claude Code JSON status payload and an optional effort override.
 * Returns:
 *   { raw: string[] (19 tab-separated fields), effortLabel: string }
 *
 * @param {string} jsonStr  - raw JSON from Claude Code
 * @param {string} effort   - value of CLAUDE_CODE_EFFORT_LEVEL (may be numeric or text)
 */
function parseFields(jsonStr, effort) {
  const fields = Array(18).fill("");
  const o = JSON.parse(jsonStr);
  const cwd = (o.workspace && o.workspace.current_dir) || o.cwd || "";
  const dir = cwd.split(/[\\/]+/).filter(Boolean).pop() || "";
  const modelFull = (o.model && o.model.display_name) || "";
  const modelShort = modelFull.split(/\s+/)[0] || "Claude";

  const cw = o.context_window || {};
  const ctxSize = cw.context_window_size || 0;
  const pctRaw = cw.used_percentage;
  const pct = Math.floor(pctRaw == null ? 0 : pctRaw);

  const cu = cw.current_usage || {};
  const tIn = Number(cu.input_tokens || 0);
  const tRead = Number(cu.cache_read_input_tokens || 0);
  const tNew = Number(cu.cache_creation_input_tokens || 0);
  const tOut = Number(cu.output_tokens || 0);
  const tUsed = tIn + tRead + tNew;

  const ctxSizeLabel = humanize(ctxSize);

  const durMs = Number((o.cost && o.cost.total_duration_ms) || 0);
  const durMins = Math.floor(durMs / 60000);
  let durFmt;
  if (durMins < 60) {
    durFmt = durMins + "m";
  } else {
    const h = Math.floor(durMins / 60);
    const m = durMins % 60;
    durFmt = m === 0 ? h + "h" : h + "h " + m + "m";
  }

  const linesAdd = Number((o.cost && o.cost.total_lines_added) || 0);
  const linesRem = Number((o.cost && o.cost.total_lines_removed) || 0);
  const sid = (o.session_id || "default").replace(/[^a-zA-Z0-9_-]/g, "");

  // Normalize effort: numeric → canonical text, then model-aware xhigh→max
  let effortCanon = canonicalEffort(effort);
  if (effortCanon === "xhigh" && !modelFull.toLowerCase().includes("opus")) {
    effortCanon = "max";
  }

  const rl = o.rate_limits || {};
  const rl5 = rl.five_hour || {};
  const rl7 = rl.seven_day || {};
  const rl5pct = rl5.used_percentage != null ? Math.floor(rl5.used_percentage) : "";
  const rl7pct = rl7.used_percentage != null ? Math.floor(rl7.used_percentage) : "";

  fields[0] = modelShort;
  fields[1] = ctxSizeLabel;
  fields[2] = dir;
  fields[3] = cwd;
  fields[4] = String(pct);
  fields[5] = humanize(tUsed);
  fields[6] = humanize(tIn);
  fields[7] = humanize(tRead);
  fields[8] = humanize(tNew);
  fields[9] = humanize(tOut);
  fields[10] = durFmt;
  fields[11] = String(linesAdd);
  fields[12] = String(linesRem);
  fields[13] = sid;
  fields[14] = effortCanon;          // canonical text, not raw input
  fields[15] = rl5pct === "" ? "" : String(rl5pct);  // percentage (number)
  fields[16] = fmtReset(rl5.resets_at);               // reset time (string)
  fields[17] = rl7pct === "" ? "" : String(rl7pct);
  fields.push(fmtReset(rl7.resets_at));               // index 18

  return {
    raw: fields,
    effortLabel: effortLabel(effortCanon),
  };
}

module.exports = { parseFields, effortLabel, canonicalEffort };
