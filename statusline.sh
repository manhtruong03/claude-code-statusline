#!/usr/bin/env bash
# claude-code-statusline v1.1
#
# Three-line status bar for Claude Code:
#   Line 1: [Model] BAR 42% | 🌿 branch* +150/-30 | 📁 project | $0.08 | ⏰ 7m 3s
#   Line 2: current ●●●●○○○○○○ 28%  ↻ 7:00pm           (5-hour rate limit)
#   Line 3: weekly  ●●●●●●●●○○ 79%  ↻ mar 10, 10:00am  (7-day rate limit)
#
# Lines 2 and 3 appear only for Claude.ai Pro/Max subscribers (the only
# sessions that receive `rate_limits.*` from Claude Code).
#
# ENV variables (all optional):
#   CLAUDE_STATUSLINE_ASCII=1     plain ASCII, no emoji/Unicode bars
#   CLAUDE_STATUSLINE_NERDFONT=1  use Nerd Font glyphs instead of emoji
#   COLORTERM=truecolor           enable 24-bit gradient bar (auto-detected)
#
# Deps: only `node` (ships with Claude Code). No jq, no git, no python required.

input=$(cat)

# ---------------------------------------------------------------------------
# Parse JSON + pre-format fields in a single node call
# ---------------------------------------------------------------------------
parsed=$(printf '%s' "$input" | node -e '
let data = "";
process.stdin.on("data", d => data += d);
process.stdin.on("end", () => {
  const fields = Array(14).fill("");
  try {
    const o = JSON.parse(data);
    const cwd = (o.workspace && o.workspace.current_dir) || o.cwd || "";
    const dir = cwd.split(/[\\\\/]+/).filter(Boolean).pop() || "";
    const modelFull = (o.model && o.model.display_name) || "";
    const modelShort = modelFull.split(/\s+/)[0] || "Claude";
    const pct = Math.floor(((o.context_window && o.context_window.used_percentage) || 0));
    const cost = Number((o.cost && o.cost.total_cost_usd) || 0);
    const costFmt = "$" + cost.toFixed(2);
    const costLevel = cost <= 0 ? "zero" : cost > 10 ? "high" : "normal";
    const durMs = Number((o.cost && o.cost.total_duration_ms) || 0);
    const durSec = Math.floor(durMs / 1000);
    const durFmt = Math.floor(durSec / 60) + "m " + (durSec % 60) + "s";
    const linesAdd = Number((o.cost && o.cost.total_lines_added) || 0);
    const linesRem = Number((o.cost && o.cost.total_lines_removed) || 0);
    const sid = (o.session_id || "default").replace(/[^a-zA-Z0-9_-]/g, "");

    const rl = o.rate_limits || {};
    const rl5 = rl.five_hour || {};
    const rl7 = rl.seven_day || {};
    const rl5pct = rl5.used_percentage != null ? Math.floor(rl5.used_percentage) : "";
    const rl7pct = rl7.used_percentage != null ? Math.floor(rl7.used_percentage) : "";

    const fmtReset = (epoch) => {
      if (!epoch) return "";
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

    fields[0]  = modelShort;
    fields[1]  = dir;
    fields[2]  = cwd;
    fields[3]  = String(pct);
    fields[4]  = costFmt;
    fields[5]  = costLevel;
    fields[6]  = durFmt;
    fields[7]  = String(linesAdd);
    fields[8]  = String(linesRem);
    fields[9]  = sid;
    fields[10] = rl5pct === "" ? "" : String(rl5pct);
    fields[11] = fmtReset(rl5.resets_at);
    fields[12] = rl7pct === "" ? "" : String(rl7pct);
    fields[13] = fmtReset(rl7.resets_at);
  } catch (e) {}
  process.stdout.write(fields.join("\t"));
});
' 2>/dev/null)

IFS=$'\t' read -r MODEL DIR CWD PCT COST_FMT COST_LEVEL DUR_FMT \
                 LINES_ADD LINES_REM SESSION_ID \
                 RL5_PCT RL5_RESET RL7_PCT RL7_RESET <<< "$parsed"

[ -z "$PCT" ] && PCT=0
[ -z "$LINES_ADD" ] && LINES_ADD=0
[ -z "$LINES_REM" ] && LINES_REM=0

# ---------------------------------------------------------------------------
# ANSI colors
# ---------------------------------------------------------------------------
GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
CYAN='\033[36m';  BLUE='\033[34m';   MAGENTA='\033[35m'
DIM='\033[2m';    BOLD='\033[1m';    RESET='\033[0m'

# ---------------------------------------------------------------------------
# Icon set — emoji / Nerd Font / ASCII
# ---------------------------------------------------------------------------
if [ "${CLAUDE_STATUSLINE_ASCII:-}" = "1" ]; then
  I_DIR="[D]"; I_BRANCH="[B]"; I_TIME="[T]"; I_RESET="->"
elif [ "${CLAUDE_STATUSLINE_NERDFONT:-}" = "1" ]; then
  I_DIR=$'\uf07b'; I_BRANCH=$'\ue725'; I_TIME=$'\uf64f'; I_RESET=$'\uf0e2'
else
  I_DIR="📁"; I_BRANCH="🌿"; I_TIME="⏰"; I_RESET="↻"
fi

# ---------------------------------------------------------------------------
# Progress bar — truecolor gradient when COLORTERM=truecolor, else solid color
# ---------------------------------------------------------------------------
render_bar() {
  local pct=$1 width=10
  [ "$pct" -gt 100 ] && pct=100
  [ "$pct" -lt 0 ] && pct=0
  local filled=$((pct * width / 100))
  local empty=$((width - filled))

  local fill_char='█' empty_char='░'
  if [ "${CLAUDE_STATUSLINE_ASCII:-}" = "1" ]; then
    fill_char='#'; empty_char='-'
  fi

  if [ "${CLAUDE_STATUSLINE_ASCII:-}" != "1" ] \
     && { [ "${COLORTERM:-}" = "truecolor" ] || [ "${COLORTERM:-}" = "24bit" ]; }; then
    # 24-bit gradient green → yellow → red across the filled segment
    local bar='' i ratio r g b rr
    for ((i=0; i<filled; i++)); do
      ratio=$(( width > 1 ? i * 100 / (width - 1) : 0 ))
      if [ "$ratio" -le 50 ]; then
        r=$((ratio * 255 / 50))
        g=$((200 + ratio * 55 / 50))
        b=0
      else
        rr=$((ratio - 50))
        r=255
        g=$((255 - rr * 205 / 50))
        b=$((rr * 50 / 50))
      fi
      bar+="\033[38;2;${r};${g};${b}m${fill_char}"
    done
    if [ "$empty" -gt 0 ]; then
      local pad; printf -v pad "%${empty}s"
      bar+="\033[38;2;80;80;80m${pad// /${empty_char}}"
    fi
    printf '%b' "${bar}${RESET}"
    return
  fi

  # Fallback: threshold-based solid color
  local color
  if   [ "$pct" -ge 90 ]; then color="$RED"
  elif [ "$pct" -ge 70 ]; then color="$YELLOW"
  else                         color="$GREEN"
  fi
  local f='' e=''
  [ "$filled" -gt 0 ] && { printf -v f "%${filled}s"; f="${f// /${fill_char}}"; }
  [ "$empty"  -gt 0 ] && { printf -v e "%${empty}s";  e="${e// /${empty_char}}"; }
  printf '%b' "${color}${f}${DIM}${e}${RESET}"
}

# ---------------------------------------------------------------------------
# Dot bar for rate limits — threshold-colored solid blocks
# ---------------------------------------------------------------------------
render_dot_bar() {
  local pct=$1 width=10
  [ "$pct" -gt 100 ] && pct=100
  [ "$pct" -lt 0 ] && pct=0
  local filled=$((pct * width / 100))
  local empty=$((width - filled))

  local fill_char='●' empty_char='○'
  if [ "${CLAUDE_STATUSLINE_ASCII:-}" = "1" ]; then
    fill_char='*'; empty_char='.'
  fi

  local color
  if   [ "$pct" -ge 90 ]; then color="$RED"
  elif [ "$pct" -ge 70 ]; then color="$YELLOW"
  else                         color="$GREEN"
  fi

  local f='' e=''
  [ "$filled" -gt 0 ] && { printf -v f "%${filled}s"; f="${f// /${fill_char}}"; }
  [ "$empty"  -gt 0 ] && { printf -v e "%${empty}s";  e="${e// /${empty_char}}"; }
  printf '%b' "${color}${f}${DIM}${e}${RESET}"
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

# ---------------------------------------------------------------------------
# Cost color based on pre-computed level
# ---------------------------------------------------------------------------
case "$COST_LEVEL" in
  high)   COST_COLOR="$RED"    ;;
  normal) COST_COLOR="$YELLOW" ;;
  *)      COST_COLOR="$DIM"    ;;
esac

SEP="${DIM}|${RESET}"

# ---------------------------------------------------------------------------
# Assemble Line 1
# ---------------------------------------------------------------------------
BAR=$(render_bar "$PCT")
LINE1="${CYAN}[${MODEL}]${RESET} ${BAR} ${PCT}%"

if [ -n "$BRANCH" ]; then
  GIT_SEG="${I_BRANCH} ${GREEN}${BRANCH}${RESET}"
  [ -n "$DIRTY" ] && GIT_SEG="${GIT_SEG}${RED}${BOLD}*${RESET}"
  if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_REM" -gt 0 ]; then
    GIT_SEG="${GIT_SEG} ${GREEN}+${LINES_ADD}${RESET}/${RED}-${LINES_REM}${RESET}"
  fi
  LINE1="${LINE1} ${SEP} ${GIT_SEG}"
fi

LINE1="${LINE1} ${SEP} ${I_DIR} ${DIR}"
LINE1="${LINE1} ${SEP} ${COST_COLOR}${COST_FMT}${RESET}"
LINE1="${LINE1} ${SEP} ${I_TIME} ${DUR_FMT}"

# ---------------------------------------------------------------------------
# Lines 2 and 3 — rate limits, shown only when Claude Code sends them
# ---------------------------------------------------------------------------
OUTPUT="$LINE1"

if [ -n "$RL5_PCT" ]; then
  BAR5=$(render_dot_bar "$RL5_PCT")
  LINE2="${DIM}current${RESET} ${BAR5} ${RL5_PCT}%"
  [ -n "$RL5_RESET" ] && LINE2="${LINE2}  ${DIM}${I_RESET} ${RL5_RESET}${RESET}"
  OUTPUT="${OUTPUT}\n${LINE2}"
fi

if [ -n "$RL7_PCT" ]; then
  BAR7=$(render_dot_bar "$RL7_PCT")
  LINE3="${DIM}weekly ${RESET} ${BAR7} ${RL7_PCT}%"
  [ -n "$RL7_RESET" ] && LINE3="${LINE3}  ${DIM}${I_RESET} ${RL7_RESET}${RESET}"
  OUTPUT="${OUTPUT}\n${LINE3}"
fi

printf '%b' "$OUTPUT"
