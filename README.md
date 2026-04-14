<div align="center">

# claude-code-statusline

**A beautiful, cross-platform two-line status bar for [Claude Code](https://code.claude.com).**

At-a-glance visibility into your model, working directory, git branch, context usage, session cost, and elapsed time — without ever leaving your terminal.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)](#install)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](#)
[![Runtime](https://img.shields.io/badge/runtime-Node.js-339933?logo=nodedotjs&logoColor=white)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#contributing)

```text
[Opus] 📁 OfficeOS | 🌿 main
████░░░░░░ 42% | $0.08 | ⏰ 7m 3s
```

</div>

---

## Why

Claude Code's default status line is informative but silent on the things that matter most during long coding sessions: **how full is my context window, how much am I spending, and how long have I been going?**

`claude-code-statusline` surfaces all of that — with a color-coded progress bar, cost tracker, and live duration — in **two compact lines** that fit any terminal. It works identically on Windows (Git Bash), macOS, and Linux, and installs with a single command.

## Features

| | |
|---|---|
| 🎯 **Context window usage** — | 10-char progress bar with threshold colors (green / yellow / red) |
| 💰 **Session cost tracking** — | Live `$0.00` formatted USD from Claude Code's cost stream |
| ⏰ **Elapsed time** — | `Xm Ys` since the session started |
| 🌿 **Git branch** — | Read directly from `.git/HEAD`, no `git` subprocess spawned |
| 📁 **Smart project name** — | Basename of `workspace.current_dir` (clean, readable) |
| 🎨 **Model badge** — | Short model name (e.g. `Opus`) in a cyan pill |
| ⚡ **Fast** — | No `jq` dependency, no `git` spawns — runs in milliseconds |
| 🔧 **Zero-config install** — | Auto-detects OS and wires `settings.json` for you |
| 🔁 **Optional live refresh** — | One flag for a ticking duration clock |

## Preview

**Low context usage** — bar in green
```
[Opus] 📁 OfficeOS | 🌿 kaopiz
████░░░░░░ 42% | $0.08 | ⏰ 7m 3s
```

**High context usage** — bar switches to yellow at 70%+
```
[Sonnet] 📁 my-app | 🌿 feature/auth
████████░░ 85% | $1.23 | ⏰ 62m 3s
```

**Critical context** — bar turns red at 90%+
```
[Opus] 📁 OfficeOS | 🌿 main
█████████░ 95% | $2.50 | ⏰ 10m 0s
```

## Install

### One-command install

```bash
git clone https://github.com/manhtruong03/claude-code-statusline.git
cd claude-code-statusline
bash install.sh
```

Then restart Claude Code. That's it.

The installer:
- Detects your OS (Windows Git Bash / macOS / Linux)
- Copies `statusline.sh` into `~/.claude/`
- Merges the `statusLine` block into `~/.claude/settings.json` (preserves all existing keys)
- Converts paths to the right format for each OS

### Manual install

If you'd rather wire it up yourself:

```bash
# 1. Copy the script
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh

# 2. Add to ~/.claude/settings.json (macOS / Linux)
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}

# 2. OR add to ~/.claude/settings.json (Windows — needs bash wrapper + native path)
{
  "statusLine": {
    "type": "command",
    "command": "bash \"C:/Users/YOU/.claude/statusline.sh\""
  }
}
```

### Uninstall

```bash
bash install.sh --uninstall
```

Removes `~/.claude/statusline.sh` and the `statusLine` block from `settings.json`, leaving all other settings intact.

## Configuration

### Live duration ticker

By default, the status line updates after each assistant message. To make the `⏰` duration tick live during idle periods, add `refreshInterval` (in seconds) to the `statusLine` block:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "refreshInterval": 5
  }
}
```

### Customize thresholds or colors

Open `~/.claude/statusline.sh` and tweak these sections — they're commented inline:

- **Bar thresholds** — currently `<70%` green, `70–89%` yellow, `≥90%` red
- **Bar width** — `BAR_WIDTH=10` (change to 20 for a wider bar)
- **Icons** — `📁` `🌿` `⏰` (swap for any Unicode / Nerd Font glyph)

## Requirements

- **[Claude Code](https://code.claude.com)** — ships with `node`, which the script uses for JSON parsing
- **Bash**
  - **Windows** — Git Bash (comes with [Git for Windows](https://git-scm.com/download/win), which Claude Code already requires)
  - **macOS / Linux** — the default shell works
- **A terminal with ANSI color + emoji support** — Windows Terminal, iTerm2, Alacritty, WezTerm, Kitty, GNOME Terminal, etc.

No `jq`, no `python`, no `git` needed on `PATH`. The script reads `.git/HEAD` directly.

## How it works

Claude Code pipes a JSON payload to the configured command on stdin every time the status line updates (after each assistant message, on permission-mode change, on vim-mode toggle, or on a `refreshInterval` tick). The script parses that JSON with `node` and extracts:

| JSON field                              | Displayed as           |
|-----------------------------------------|------------------------|
| `model.display_name`                    | `[Opus]` (first word)  |
| `workspace.current_dir`                 | `📁 OfficeOS`          |
| `context_window.used_percentage`        | Progress bar + `42%`   |
| `cost.total_cost_usd`                   | `$0.08`                |
| `cost.total_duration_ms`                | `⏰ 7m 3s`             |
| *(from `.git/HEAD` of the cwd's repo)*  | `🌿 main`              |

Full schema in the [official status line docs](https://code.claude.com/docs/en/statusline#available-data).

## Troubleshooting

<details>
<summary><b>Status line doesn't appear after install</b></summary>

- Restart Claude Code — settings reload on the next interaction
- Verify the script is executable: `ls -la ~/.claude/statusline.sh`
- Run `claude --debug` to see any stderr from the status line command
- On Windows: the `command` in `settings.json` must use a **native** Windows path (`C:/Users/…`), not a Git Bash path (`/c/Users/…`). The installer handles this automatically via `cygpath`.
</details>

<details>
<summary><b>Emojis render as boxes or tofu</b></summary>

- Windows: make sure your terminal font includes emoji glyphs — [Cascadia Code](https://github.com/microsoft/cascadia-code) or any [Nerd Font](https://www.nerdfonts.com/) works
- Ensure your terminal is set to UTF-8 output
</details>

<details>
<summary><b>Context percentage shows 0% at session start</b></summary>

That's correct — `context_window.used_percentage` is `null` until the first API response lands. After the first message it populates and updates on every turn.
</details>

<details>
<summary><b>I use Fish / Zsh / something else — will this work?</b></summary>

The **installer** needs bash to run once. After install, the status line itself is invoked by Claude Code, which runs it through bash (on every platform) — so your interactive shell doesn't matter.
</details>

## Contributing

PRs and issues very welcome. A few ideas on the wishlist:

- [ ] Optional `session_name` display when set via `/rename`
- [ ] Rate-limit usage segment (`5h: 23% | 7d: 41%`) for Pro/Max users
- [ ] Themeable color palettes (Dracula / Solarized / Nord)
- [ ] Nerd Font icon variants
- [ ] PowerShell port for non-Git-Bash Windows users

Before submitting, please test the installer on at least one OS:

```bash
bash install.sh
bash install.sh --uninstall
```

## Credits

Inspired by the official [Claude Code status line documentation](https://code.claude.com/docs/en/statusline) and the [`ccstatusline`](https://github.com/sirmalloc/ccstatusline) and [`starship-claude`](https://github.com/martinemde/starship-claude) community projects.

## License

[MIT](./LICENSE) © manhtruong03
