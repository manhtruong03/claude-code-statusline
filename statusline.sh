#!/usr/bin/env bash
# claude-code-statusline v1.2.2
#
# Three-line status bar for Claude Code, designed for power users who want
# detailed token management and rate-limit visibility instead of a progress bar:
#
#   Line 1: [Opus·1M·🧠H] | 🌿 branch* | 📁 project | ⏰ 87m
#   Line 2: ctx 124k/1M (42%) · in 58k · read 60k · new 2k · out 4k
#   Line 3: current 28% ↻ 7:00pm | weekly 79% ↻ mar 10, 10:00am
#
# Compact decisions:
#   • Thinking Effort abbreviated inside the badge: Mx/XH/H/Md/L (numeric 1–6 or text).
#   • Lines diff (+N/-M) removed — git status only shows branch + dirty flag.
#   • Duration shown in minute resolution ("87m", "2h 15m") — never seconds.
#
# Line 3 appears only for Claude.ai Pro/Max subscribers (the only sessions
# that receive `rate_limits.*` from Claude Code).
#
# ENV variables (all optional):
#   CLAUDE_STATUSLINE_ASCII=1     plain ASCII, no emoji/Unicode
#   CLAUDE_STATUSLINE_NERDFONT=1  use Nerd Font glyphs instead of emoji
#
# Deps: only `node` (ships with Claude Code). No jq, no git, no python required.

input=$(cat)

# ---------------------------------------------------------------------------
# Parse JSON + read settings + pre-format everything in one node call
# ---------------------------------------------------------------------------
parsed=$(printf '%s' "$input" | node -e '
let data = "";
process.stdin.on("data", d => data += d);
process.stdin.on("end", () => {
  const fields = Array(18).fill("");
  try {
    const fs  = require("fs");
    const os  = require("os");
    const o   = JSON.parse(data);
    const cwd = (o.workspace && o.workspace.current_dir) || o.cwd || "";
    const dir = cwd.split(/[\\\\/]+/).filter(Boolean).pop() || "";
    const modelFull  = (o.model && o.model.display_name) || "";
    const modelShort = modelFull.split(/\s+/)[0] || "Claude";

    // --- Context window ---------------------------------------------------
    const cw       = o.context_window || {};
    const ctxSize  = cw.context_window_size || 0;
    const pctRaw   = cw.used_percentage;
    const pct      = Math.floor(pctRaw == null ? 0 : pctRaw);

    // current_usage is null before the first API call
    const cu       = cw.current_usage || {};
    const tIn      = Number(cu.input_tokens || 0);
    const tRead    = Number(cu.cache_read_input_tokens || 0);
    const tNew     = Number(cu.cache_creation_input_tokens || 0);
    const tOut     = Number(cu.output_tokens || 0);
    // Per docs: context-counting tokens = in + cache_read + cache_creation
    const tUsed    = tIn + tRead + tNew;

    // --- Format helpers ---------------------------------------------------
    const humanize = (n) => {
      if (n >= 1000000) return (n/1000000).toFixed(1).replace(/\.0$/, "") + "M";
      if (n >= 1000)    return Math.round(n/1000) + "k";
      return String(n);
    };
    const ctxSizeLabel = humanize(ctxSize);

    // --- Session / cost / duration ---------------------------------------
    // Duration — minute-resolution only; seconds are never displayed.
    // < 60m  → "Xm"     (0m during the first minute)
    // ≥ 60m  → "Xh Ym"  (or "Xh" when minutes are 0)
    const durMs   = Number((o.cost && o.cost.total_duration_ms) || 0);
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

    // --- Thinking effort from ~/.claude/settings.json --------------------
    // Numeric scale: 1=none, 2=low, 3=medium, 4=high, 5=xhigh, 6=max
    const EFFORT_CANONICAL = {
      "1": "none", "2": "low", "3": "medium", "4": "high", "5": "xhigh", "6": "max",
    };
    let effortRaw = "";
    try {
      const settingsPath = os.homedir() + "/.claude/settings.json";
      if (fs.existsSync(settingsPath)) {
        const s = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
        // Claude Code stores effort in effortLevel (current) or env.CLAUDE_CODE_EFFORT_LEVEL (legacy)
        effortRaw = s.effortLevel || (s.env && s.env.CLAUDE_CODE_EFFORT_LEVEL) || "";
      }
    } catch (e) {}
    // Normalize numeric → canonical text; unknown values pass through lowercased.
    let effort = EFFORT_CANONICAL[String(effortRaw)] || effortRaw.toLowerCase() || "none";
    const modelLower = modelFull.toLowerCase();
    // Haiku has no thinking effort setting — always hide the badge.
    if (modelLower.includes("haiku")) {
      effort = "none";
    // xhigh only exists on Opus; for Sonnet it maps to max (highest level).
    } else if (effort === "xhigh" && !modelLower.includes("opus")) {
      effort = "max";
    }

    // --- Rate limits ------------------------------------------------------
    const rl  = o.rate_limits || {};
    const rl5 = rl.five_hour  || {};
    const rl7 = rl.seven_day  || {};
    const rl5pct = rl5.used_percentage != null ? Math.floor(rl5.used_percentage) : "";
    const rl7pct = rl7.used_percentage != null ? Math.floor(rl7.used_percentage) : "";

    const fmtReset = (epoch) => {
      if (!epoch) return "-";
      const d = new Date(epoch * 1000);
      const now = new Date();
      const sameDay = d.toDateString() === now.toDateString();
      const time = d.toLocaleTimeString("en-US", {
        hour: "numeric", minute: "2-digit", hour12: true
      }).toLowerCase().replace(/\s+/g, "");
      if (sameDay) return time;
      const md = d.toLocaleDateString("en-US", {
        month: "short", day: "numeric"
      }).toLowerCase();
      return md + ", " + time;
    };

    // Fields are joined with \x01 (SOH) — a non-whitespace byte that never
    // appears in file paths, model names, or time strings. This prevents bash
    // IFS from collapsing consecutive separators when a field is empty (which
    // would silently shift every subsequent variable by one position).
    const SEP = "\x01";

    fields[0]  = modelShort;
    fields[1]  = ctxSizeLabel;         // "1M" / "200k"
    fields[2]  = dir   || "-";         // sentinel prevents IFS collapse
    fields[3]  = cwd   || "-";
    fields[4]  = String(pct);
    fields[5]  = humanize(tUsed);      // "124k"
    fields[6]  = humanize(tIn);        // "58k"
    fields[7]  = humanize(tRead);      // "60k"
    fields[8]  = humanize(tNew);       // "2k"
    fields[9]  = humanize(tOut);       // "4k"
    fields[10] = durFmt;
    fields[11] = String(linesAdd);
    fields[12] = String(linesRem);
    fields[13] = sid;
    fields[14] = effort;               // canonical text, never empty ("none" when unset)
    fields[15] = rl5pct === "" ? "-" : String(rl5pct);
    fields[16] = fmtReset(rl5.resets_at);
    fields[17] = rl7pct === "" ? "-" : String(rl7pct);
    fields[18] = fmtReset(rl7.resets_at);
  } catch (e) {}
  process.stdout.write(fields.join("\x01"));
});
' 2>/dev/null)

IFS=$'\001' read -r MODEL CTX_SIZE DIR CWD PCT \
                 T_USED T_IN T_READ T_NEW T_OUT \
                 DUR_FMT LINES_ADD LINES_REM SESSION_ID \
                 EFFORT \
                 RL5_PCT RL5_RESET RL7_PCT RL7_RESET <<< "$parsed"

[ -z "$PCT" ]       && PCT=0
[ -z "$LINES_ADD" ] && LINES_ADD=0
[ -z "$LINES_REM" ] && LINES_REM=0
# Restore sentinel "-" back to empty for display purposes
[ "$DIR"      = "-" ] && DIR=""
[ "$CWD"      = "-" ] && CWD=""
[ "$RL5_PCT"  = "-" ] && RL5_PCT=""
[ "$RL5_RESET" = "-" ] && RL5_RESET=""
[ "$RL7_PCT"  = "-" ] && RL7_PCT=""
[ "$RL7_RESET" = "-" ] && RL7_RESET=""

# ---------------------------------------------------------------------------
# ANSI colors
#   GRAY replaces the old DIM (\033[2m) for structural chars — gives stable,
#   readable contrast on both dark and light terminals. DIM is retained only
#   for the fresh-session placeholder.
# ---------------------------------------------------------------------------
GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
CYAN='\033[36m';  BLUE='\033[34m';   MAGENTA='\033[35m'
GRAY='\033[38;5;245m'
DIM='\033[2m';    BOLD='\033[1m';    RESET='\033[0m'

# ---------------------------------------------------------------------------
# Icons — emoji / Nerd Font / ASCII
# ---------------------------------------------------------------------------
if [ "${CLAUDE_STATUSLINE_ASCII:-}" = "1" ]; then
  I_DIR="[D]"; I_BRANCH="[B]"; I_TIME="[T]"; I_RESET="->"; I_THINK="[E]"
elif [ "${CLAUDE_STATUSLINE_NERDFONT:-}" = "1" ]; then
  I_DIR=$'\uf07b'; I_BRANCH=$'\ue725'; I_TIME=$'\uf64f'; I_RESET=$'\uf0e2'; I_THINK=$'\uf0eb'
else
  I_DIR="📁"; I_BRANCH="🌿"; I_TIME="⏰"; I_RESET="↻"; I_THINK="🧠"
fi

# ---------------------------------------------------------------------------
# Context % → color (used for both the percent text and token total)
# ---------------------------------------------------------------------------
if   [ "$PCT" -ge 90 ]; then PCT_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then PCT_COLOR="$YELLOW"
else                         PCT_COLOR="$GREEN"
fi

# ---------------------------------------------------------------------------
# Thinking effort → display label + color
#   max   → Mx (red)      xhigh → XH (bold magenta)
#   high  → H  (magenta)  medium → Md (yellow, avoids "M" ambiguity with Max)
#   low   → L  (gray)     none/unknown → hidden
# ---------------------------------------------------------------------------
case "$EFFORT" in
  max)    EFFORT_LABEL="Mx"; EFFORT_COLOR="$RED"     ;;
  xhigh)  EFFORT_LABEL="XH"; EFFORT_COLOR="${BOLD}${MAGENTA}" ;;
  high)   EFFORT_LABEL="H";  EFFORT_COLOR="$MAGENTA" ;;
  medium) EFFORT_LABEL="Md"; EFFORT_COLOR="$YELLOW"  ;;
  low)    EFFORT_LABEL="L";  EFFORT_COLOR="$GRAY"    ;;
  *)      EFFORT_LABEL="";   EFFORT_COLOR=""         ;;
esac

# ---------------------------------------------------------------------------
# Rate-limit colors (per-window)
# ---------------------------------------------------------------------------
rl_color() {
  local p=$1
  if   [ "$p" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$p" -ge 70 ]; then printf '%s' "$YELLOW"
  else                       printf '%s' "$GREEN"
  fi
}

# ---------------------------------------------------------------------------
# Git branch + dirty indicator — cached 5s to keep status line snappy
# ---------------------------------------------------------------------------
GIT_CACHE="${TMPDIR:-/tmp}/cc-statusline-git-${SESSION_ID:-default}"
CACHE_MAX_AGE=5

git_cache_fresh() {
  [ -f "$GIT_CACHE" ] || return 1
  local mt age
  mt=$(stat -c %Y "$GIT_CACHE" 2>/dev/null || stat -f %m "$GIT_CACHE" 2>/dev/null || echo 0)
  age=$(( $(date +%s) - mt ))
  [ "$age" -le "$CACHE_MAX_AGE" ]
}

BRANCH=""
DIRTY=""
if git_cache_fresh; then
  IFS='|' read -r BRANCH DIRTY < "$GIT_CACHE"
else
  if [ -n "$CWD" ] && command -v git >/dev/null 2>&1; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
      if [ -n "$(git -C "$CWD" status --porcelain 2>/dev/null | head -1)" ]; then
        DIRTY="*"
      fi
    fi
  fi
  # Fallback: read .git/HEAD directly if `git` isn't available
  if [ -z "$BRANCH" ] && [ -n "$CWD" ]; then
    search_dir="$CWD"
    while [ -n "$search_dir" ] && [ "$search_dir" != "/" ]; do
      if [ -f "$search_dir/.git/HEAD" ]; then
        head_ref=$(head -1 "$search_dir/.git/HEAD" 2>/dev/null)
        case "$head_ref" in
          "ref: refs/heads/"*) BRANCH="${head_ref#ref: refs/heads/}" ;;
          *) BRANCH="${head_ref:0:7}" ;;
        esac
        break
      fi
      search_dir="${search_dir%/*}"
    done
  fi
  mkdir -p "$(dirname "$GIT_CACHE")" 2>/dev/null
  printf '%s|%s' "$BRANCH" "$DIRTY" > "$GIT_CACHE"
fi

SEP="${GRAY}|${RESET}"
DOT="${GRAY}·${RESET}"

# ---------------------------------------------------------------------------
# Line 1: [Model · CtxSize · 🧠 effort] | branch* +N/-M | dir | duration
# (Thinking Effort now lives inside the model badge for compactness)
# ---------------------------------------------------------------------------
LINE1="${CYAN}[${MODEL}${RESET}"
if [ -n "$CTX_SIZE" ] && [ "$CTX_SIZE" != "0" ]; then
  LINE1="${LINE1}${GRAY}·${RESET}${CYAN}${CTX_SIZE}${RESET}"
fi
if [ -n "$EFFORT_LABEL" ]; then
  LINE1="${LINE1}${GRAY}·${RESET}${I_THINK}${EFFORT_COLOR}${EFFORT_LABEL}${RESET}"
fi
LINE1="${LINE1}${CYAN}]${RESET}"

if [ -n "$BRANCH" ]; then
  GIT_SEG="${I_BRANCH} ${GREEN}${BRANCH}${RESET}"
  [ -n "$DIRTY" ] && GIT_SEG="${GIT_SEG}${RED}${BOLD}*${RESET}"
  LINE1="${LINE1} ${SEP} ${GIT_SEG}"
fi

LINE1="${LINE1} ${SEP} ${I_DIR} ${DIR}"
LINE1="${LINE1} ${SEP} ${I_TIME} ${DUR_FMT}"

# ---------------------------------------------------------------------------
# Line 2: token breakdown
#   ctx 124k/1M (42%) · in 58k · read 60k · new 2k · out 4k
# Labels in normal weight; only separators and the "/" use gray for structure.
# (hidden when current_usage is null — before first API call)
# ---------------------------------------------------------------------------
LINE2=""
if [ -n "$T_USED" ] && [ "$T_USED" != "0" ]; then
  LINE2="ctx ${BOLD}${PCT_COLOR}${T_USED}${RESET}${GRAY}/${CTX_SIZE:-?}${RESET} ${GRAY}(${PCT_COLOR}${PCT}%${GRAY})${RESET}"
  LINE2="${LINE2} ${DOT} in ${T_IN}"
  [ -n "$T_READ" ] && [ "$T_READ" != "0" ] && LINE2="${LINE2} ${DOT} read ${T_READ}"
  [ -n "$T_NEW" ]  && [ "$T_NEW"  != "0" ] && LINE2="${LINE2} ${DOT} new ${T_NEW}"
  [ -n "$T_OUT" ]  && [ "$T_OUT"  != "0" ] && LINE2="${LINE2} ${DOT} out ${T_OUT}"
else
  LINE2="${GRAY}ctx 0/${CTX_SIZE:-?} (0%) · awaiting first response${RESET}"
fi

# ---------------------------------------------------------------------------
# Line 3: rate limits combined
#   current 28% ↻ 7:00pm | weekly 79% ↻ mar 10, 10:00am
# Labels & reset times in normal weight; arrows in gray.
# ---------------------------------------------------------------------------
LINE3=""
if [ -n "$RL5_PCT" ]; then
  RL5_COLOR=$(rl_color "$RL5_PCT")
  LINE3="current ${BOLD}${RL5_COLOR}${RL5_PCT}%${RESET}"
  [ -n "$RL5_RESET" ] && LINE3="${LINE3} ${GRAY}${I_RESET}${RESET} ${RL5_RESET}"
fi
if [ -n "$RL7_PCT" ]; then
  RL7_COLOR=$(rl_color "$RL7_PCT")
  [ -n "$LINE3" ] && LINE3="${LINE3} ${SEP} "
  LINE3="${LINE3}weekly ${BOLD}${RL7_COLOR}${RL7_PCT}%${RESET}"
  [ -n "$RL7_RESET" ] && LINE3="${LINE3} ${GRAY}${I_RESET}${RESET} ${RL7_RESET}"
fi

# ---------------------------------------------------------------------------
# Emit
# ---------------------------------------------------------------------------
OUTPUT="$LINE1"
[ -n "$LINE2" ] && OUTPUT="${OUTPUT}\n${LINE2}"
[ -n "$LINE3" ] && OUTPUT="${OUTPUT}\n${LINE3}"
printf '%b' "$OUTPUT"
