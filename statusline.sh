#!/usr/bin/env bash
# Claude Code 2-line statusLine matching the docs' multi-line example:
#   Line 1: [Model] 📁 project | 🌿 branch
#   Line 2: ▓▓▓▓░░░░░░ 42% | $0.08 | ⏰ 7m 3s
#
# Uses `node` for JSON parsing because `jq` is typically absent in
# Git Bash on Windows. Claude Code (Node-based) guarantees `node` on PATH.

input=$(cat)

# ---------------------------------------------------------------------------
# Parse JSON payload via node → TAB-separated fields
# ---------------------------------------------------------------------------
parsed=$(printf '%s' "$input" | node -e '
let data = "";
process.stdin.on("data", d => data += d);
process.stdin.on("end", () => {
  try {
    const o = JSON.parse(data);
    const cwd = (o.workspace && o.workspace.current_dir) || o.cwd || "";
    const dir = cwd.split(/[\\\\/]+/).filter(Boolean).pop() || "";
    const model = (o.model && o.model.display_name) || "";
    const pctRaw = o.context_window && o.context_window.used_percentage;
    const pct = Math.floor(pctRaw == null ? 0 : pctRaw);
    const cost = (o.cost && o.cost.total_cost_usd) || 0;
    const durMs = (o.cost && o.cost.total_duration_ms) || 0;
    process.stdout.write([model, dir, pct, cost, durMs].join("\t"));
  } catch (e) {
    process.stdout.write("\t\t0\t0\t0");
  }
});
' 2>/dev/null)

IFS=$'\t' read -r MODEL DIR PCT COST DURATION_MS <<< "$parsed"

# Short model name: first word only ("Opus 4.6 (1M context)" → "Opus")
MODEL_SHORT="${MODEL%% *}"
[ -z "$MODEL_SHORT" ] && MODEL_SHORT="Claude"

# ---------------------------------------------------------------------------
# Git branch (cached read of .git/HEAD — avoids spawning `git`)
# ---------------------------------------------------------------------------
BRANCH=""
search_dir="$PWD"
[ -n "$DIR" ] && search_dir=$(node -e '
const o=JSON.parse(process.argv[1]);
process.stdout.write((o.workspace && o.workspace.current_dir) || o.cwd || "");
' "$input" 2>/dev/null)
[ -z "$search_dir" ] && search_dir="$PWD"
cur="$search_dir"
while [ -n "$cur" ] && [ "$cur" != "/" ] && [ "$cur" != "." ]; do
  if [ -f "$cur/.git/HEAD" ]; then
    head_ref=$(head -1 "$cur/.git/HEAD" 2>/dev/null)
    case "$head_ref" in
      "ref: refs/heads/"*) BRANCH="${head_ref#ref: refs/heads/}" ;;
      *) BRANCH="${head_ref:0:7}" ;;
    esac
    break
  fi
  cur="${cur%/*}"
done

# ---------------------------------------------------------------------------
# Progress bar (10 chars) with threshold colors
#   <70%  green   |   70–89%  yellow   |   ≥90%  red
# ---------------------------------------------------------------------------
PCT="${PCT%.*}"
[ -z "$PCT" ] && PCT=0
BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
EMPTY=$((BAR_WIDTH - FILLED))

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
RESET='\033[0m'

if   [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else                         BAR_COLOR="$GREEN"
fi

BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /█}"
[ "$EMPTY"  -gt 0 ] && printf -v PAD  "%${EMPTY}s"  && BAR="${BAR}${PAD// /░}"

# ---------------------------------------------------------------------------
# Cost + duration
# ---------------------------------------------------------------------------
COST_FMT=$(printf '$%.2f' "$COST" 2>/dev/null)
[ -z "$COST_FMT" ] && COST_FMT='$0.00'

DURATION_SEC=$((DURATION_MS / 1000))
MINS=$((DURATION_SEC / 60))
SECS=$((DURATION_SEC % 60))

# ---------------------------------------------------------------------------
# Emit two lines
# ---------------------------------------------------------------------------
BRANCH_PART=""
[ -n "$BRANCH" ] && BRANCH_PART=" | 🌿 ${BRANCH}"

printf '%b\n' "${CYAN}[${MODEL_SHORT}]${RESET} 📁 ${DIR}${BRANCH_PART}"
printf '%b'   "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏰ ${MINS}m ${SECS}s"
