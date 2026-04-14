#!/usr/bin/env bash
# Cross-platform installer for the Claude Code statusLine bundle.
#
# Works on:
#   • Windows  — Git Bash / MSYS2 / Cygwin
#   • macOS    — default /bin/bash or zsh users running `bash install.sh`
#   • Linux    — any distro with bash
#
# What it does:
#   1. Detects OS, locates Claude Code config dir (~/.claude)
#   2. Copies statusline.sh into ~/.claude/
#   3. Merges the `statusLine` block into ~/.claude/settings.json,
#      preserving any existing keys; creates the file if missing.
#   4. Converts paths correctly for each OS (Windows needs a bash wrapper
#      with a Windows-style path, Unix uses the script path directly).
#
# Usage:
#   bash install.sh            # install with defaults
#   bash install.sh --uninstall  # remove the statusLine block

set -e

# ---------------------------------------------------------------------------
# Locate source script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_SCRIPT="$SCRIPT_DIR/statusline.sh"

if [ ! -f "$SRC_SCRIPT" ]; then
  echo "ERROR: statusline.sh not found next to install.sh" >&2
  echo "       Expected at: $SRC_SCRIPT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Detect OS
# ---------------------------------------------------------------------------
case "$(uname -s 2>/dev/null)" in
  Linux*)                OS=linux   ;;
  Darwin*)               OS=macos   ;;
  MINGW*|MSYS*|CYGWIN*)  OS=windows ;;
  *)                     OS=unknown ;;
esac

# ---------------------------------------------------------------------------
# Verify node is available (Claude Code ships with it, so this should pass)
# ---------------------------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: 'node' not found on PATH." >&2
  echo "       Install Claude Code first — it provides node." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
CLAUDE_DIR="$HOME/.claude"
DEST_SCRIPT="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"

# ---------------------------------------------------------------------------
# Uninstall path
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--uninstall" ]; then
  echo "Uninstalling Claude Code statusLine..."
  [ -f "$DEST_SCRIPT" ] && rm -f "$DEST_SCRIPT" && echo "  removed $DEST_SCRIPT"
  if [ -f "$SETTINGS" ]; then
    node -e '
const fs = require("fs");
const p = process.argv[1];
try {
  const o = JSON.parse(fs.readFileSync(p, "utf8"));
  delete o.statusLine;
  fs.writeFileSync(p, JSON.stringify(o, null, 2) + "\n");
  console.log("  removed statusLine block from " + p);
} catch (e) {
  console.error("  settings.json not readable — skipped");
}
' "$SETTINGS"
  fi
  echo "Done."
  exit 0
fi

# ---------------------------------------------------------------------------
# Install: copy script
# ---------------------------------------------------------------------------
echo "Detected OS:  $OS"
echo "Claude dir:   $CLAUDE_DIR"

cp "$SRC_SCRIPT" "$DEST_SCRIPT"
chmod +x "$DEST_SCRIPT" 2>/dev/null || true
echo "Installed:    $DEST_SCRIPT"

# ---------------------------------------------------------------------------
# Build the `command` string for settings.json
#   • Windows:  bash "C:/Users/.../statusline.sh"
#     (Claude Code on Windows runs commands through Git Bash; the path
#      inside the quotes must be a native Windows path, not /c/Users/...)
#   • Unix:     /Users/.../.claude/statusline.sh  (use $HOME-expanded absolute)
# ---------------------------------------------------------------------------
if [ "$OS" = "windows" ]; then
  if command -v cygpath >/dev/null 2>&1; then
    WIN_PATH=$(cygpath -m "$DEST_SCRIPT")
  else
    WIN_PATH=$(echo "$DEST_SCRIPT" | sed -E 's|^/([a-zA-Z])/|\1:/|')
  fi
  CMD_STR="bash \"$WIN_PATH\""
else
  CMD_STR="$DEST_SCRIPT"
fi

# ---------------------------------------------------------------------------
# Merge statusLine block into settings.json (preserve other keys)
# ---------------------------------------------------------------------------
node -e '
const fs = require("fs");
const settingsPath = process.argv[1];
const cmd = process.argv[2];

let obj = {};
if (fs.existsSync(settingsPath)) {
  try {
    obj = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
  } catch (e) {
    const backup = settingsPath + ".backup-" + Date.now();
    fs.copyFileSync(settingsPath, backup);
    console.error("  WARNING: existing settings.json is invalid JSON.");
    console.error("           Backed up to: " + backup);
    obj = {};
  }
}

obj.statusLine = { type: "command", command: cmd };
fs.writeFileSync(settingsPath, JSON.stringify(obj, null, 2) + "\n");
' "$SETTINGS" "$CMD_STR"

echo "Configured:   $SETTINGS"
echo "Command:      $CMD_STR"
echo ""
echo "Done. Restart Claude Code to see the new status line."
