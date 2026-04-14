<div align="center">

# claude-code-statusline

**A beautiful, feature-rich three-line status bar for [Claude Code](https://code.claude.com).**

At-a-glance visibility into your model, context usage, git state, session cost, elapsed time, and Pro/Max rate limits — all without leaving your terminal.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)](#install)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](#)
[![Runtime](https://img.shields.io/badge/runtime-Node.js-339933?logo=nodedotjs&logoColor=white)](#)
[![Version](https://img.shields.io/badge/version-1.1.0-8A2BE2)](./CHANGELOG.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#contributing)

```text
[Opus] ████░░░░░░ 42% | 🌿 main* +150/-30 | 📁 OfficeOS | $0.08 | ⏰ 7m 3s
current ●●●○○○○○○○ 28%  ↻ 7:00pm
weekly  ●●●●●●●○○○ 79%  ↻ mar 10, 10:00am
```

</div>

---

## Why

Claude Code's default status line is informative but silent on the things that matter most during long coding sessions: **how full is my context, how dirty is my branch, how much am I spending, and how close am I to my rate limits?**

`claude-code-statusline` surfaces all of that — with a **true-color gradient** context bar, **dirty-branch indicator**, **lines-changed counters**, **cost tracker**, and **5-hour / 7-day rate-limit quotas** with human-friendly reset times — across three compact lines that work on any terminal. It installs with a single command and has **zero runtime dependencies** beyond the `node` binary that Claude Code already ships.

## Features

### Line 1 — live session snapshot

| | |
|---|---|
| 🎨 **True-color gradient bar** | 24-bit green→yellow→red gradient across the filled segment; auto-falls back to solid threshold colors on 256-color terminals |
| 🌿 **Dirty branch indicator** | `main*` in red when uncommitted changes are detected |
| 📝 **Lines changed** | `+150/-30` from `cost.total_lines_added/removed`; hidden when both are zero |
| 💰 **Smart cost color** | Dim at `$0.00`, yellow normal, red when `>$10` |
| ⏰ **Elapsed time** | `Xm Ys` from `cost.total_duration_ms` |
| 📁 **Project basename** | Clean `workspace.current_dir` basename, no noisy full paths |
| 🎯 **Short model badge** | First word of `model.display_name` (`Opus`, `Sonnet`, `Haiku`) |

### Lines 2 & 3 — rate-limit dashboard (Pro/Max only)

| | |
|---|---|
| 🕐 **5-hour rolling window** | `current` row with color-coded dot bar + percentage + reset time |
| 📆 **7-day rolling window** | `weekly` row with color-coded dot bar + percentage + reset time |
| ⏱ **Smart reset formatting** | `7:00pm` if reset today, else `mar 10, 10:00am` |
| 👻 **Auto-hide for free users** | Rows vanish entirely when `rate_limits` is absent from the payload |

### Engineering

| | |
|---|---|
| ⚡ **Fast** | ~50ms typical runtime — single `node` JSON parse, no subprocess fan-out |
| 🪶 **Zero dependencies** | No `jq`, no `python`, no `git` required on `PATH` — only `node` (bundled with Claude Code) |
| 🧠 **Git caching** | `git status --porcelain` cached 5s per session to avoid lag on big repos |
| 🛟 **Graceful fallback** | Reads `.git/HEAD` directly if `git` is missing |
| 🎛 **ENV-driven theming** | Swap between emoji / Nerd Font / pure ASCII with one environment variable |

## Preview

### Active Pro/Max session
```
[Opus] ████░░░░░░ 42% | 🌿 main* +150/-30 | 📁 OfficeOS | $0.08 | ⏰ 7m 3s
current ●●●○○○○○○○ 28%  ↻ 7:00pm
weekly  ●●●●●●●○○○ 79%  ↻ mar 10, 10:00am
```

### Fresh session, free tier (no rate limits)
```
[Sonnet] ░░░░░░░░░░ 0% | 🌿 main | 📁 my-app | $0.00 | ⏰ 0m 0s
```

### Critical context + hot wallet (90%+ usage, >$10 spend)
```
[Opus] █████████░ 95% | 🌿 feature/auth* +820/-340 | 📁 core | $12.80 | ⏰ 45m 12s
current ●●●●●●●●●○ 92%  ↻ 3:15pm
weekly  ●●●●●●●○○○ 71%  ↻ apr 21, 9:00am
```

### ASCII-only mode (CI / limited terminals)
```
[Opus] ####------ 42% | [B] main* +150/-30 | [D] OfficeOS | $0.08 | [T] 7m 3s
current ** ........ 28%  -> 7:00pm
weekly  *******... 79%  -> mar 10, 10:00am
```

## Install

### One-command install

```bash
git clone https://github.com/manhtruong03/claude-code-statusline.git
cd claude-code-statusline
bash install.sh
```

Then restart Claude Code.

The installer:
- Detects your OS (Windows Git Bash / macOS / Linux)
- Copies `statusline.sh` into `~/.claude/`
- Merges the `statusLine` block into `~/.claude/settings.json` (preserves all existing keys)
- Converts paths to the right format for each OS

### Manual install

<details>
<summary>Click for manual wiring</summary>

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
</details>

### Uninstall

```bash
bash install.sh --uninstall
```

Removes `~/.claude/statusline.sh` and the `statusLine` block from `settings.json`, leaving all other settings intact.

## Configuration

All configuration happens through environment variables — no config file to maintain.

| Variable | Effect |
|---|---|
| `COLORTERM=truecolor` | Enable 24-bit gradient bar (most modern terminals set this automatically) |
| `CLAUDE_STATUSLINE_ASCII=1` | Plain ASCII mode — no emoji, no Unicode block characters |
| `CLAUDE_STATUSLINE_NERDFONT=1` | Swap emoji icons for [Nerd Font](https://www.nerdfonts.com/) glyphs |

Set any of these in your shell profile before launching Claude Code, for example:

```bash
export CLAUDE_STATUSLINE_NERDFONT=1   # in ~/.bashrc or ~/.zshrc
```

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

### Customize colors or thresholds

Open `~/.claude/statusline.sh` — the interesting sections are clearly commented:

- **Bar thresholds** — `<70%` green, `70–89%` yellow, `≥90%` red (fallback mode)
- **Gradient stops** — green `(0,200,0)` → yellow `(255,255,0)` → red `(255,50,50)`
- **Bar width** — `width=10` (bump to 20 for a wider bar)
- **Cost levels** — `zero` / `normal` / `high` boundaries in the node parsing block

## Requirements

- **[Claude Code](https://code.claude.com)** — provides the `node` binary used internally
- **Bash**
  - **Windows** — [Git Bash](https://git-scm.com/download/win) (bundled with Git for Windows, already required by Claude Code)
  - **macOS / Linux** — default shell
- **A terminal with ANSI color + emoji support**
  - Best: iTerm2, Alacritty, WezTerm, Kitty, Windows Terminal
  - Truecolor-capable: all of the above (auto-detected via `$COLORTERM`)

No `jq`, no `python`, no `git` required on `PATH`.

## How it works

Claude Code pipes a JSON payload to your configured command on stdin every time the status line updates (after each assistant message, on permission-mode change, on vim-mode toggle, or on a `refreshInterval` tick). The script extracts these fields:

| JSON path                                         | Rendered as                        |
|---------------------------------------------------|------------------------------------|
| `model.display_name`                              | `[Opus]` (first word, cyan)        |
| `workspace.current_dir`                           | `📁 OfficeOS` (basename only)      |
| `context_window.used_percentage`                  | Gradient bar + `42%`               |
| `cost.total_cost_usd`                             | `$0.08` (color by level)           |
| `cost.total_duration_ms`                          | `⏰ 7m 3s`                         |
| `cost.total_lines_added` / `total_lines_removed`  | `+150/-30` (green/red, zero-hide)  |
| `rate_limits.five_hour.used_percentage`           | `current ●●●○○○○○○○ 28%`           |
| `rate_limits.five_hour.resets_at`                 | `↻ 7:00pm` / `↻ mar 10, 10:00am`   |
| `rate_limits.seven_day.*`                         | `weekly` row, same format          |
| *(from `.git/HEAD` + `.git/index`)*               | `🌿 main*` (dirty-aware)           |

Full JSON schema in the [official status line docs](https://code.claude.com/docs/en/statusline#available-data).

## Comparison with similar projects

| | this repo | [kamranahmedse](https://github.com/kamranahmedse/claude-statusline) | [ccstatusline](https://github.com/sirmalloc/ccstatusline) | [kcchien](https://github.com/kcchien/claude-code-statusline) |
|---|:---:|:---:|:---:|:---:|
| Rate-limit dashboard            | ✅ | ✅ | ✅ | ✅ |
| Truecolor gradient bar          | ✅ | ❌ | ❌ | ✅ |
| Dirty branch indicator          | ✅ | ✅ | ✅ | ✅ |
| Lines diff `+N/-M`              | ✅ | ❌ | ❌ | ✅ |
| Human reset time (`7:00pm`)     | ✅ | ✅ | ❌ | ❌ |
| Cross-platform installer        | ✅ | ✅ | ✅ | ❌ |
| Zero runtime deps (no jq/python)| ✅ | ❌ | ❌ | ❌ |
| Single-file readable bash       | ✅ | ❌ | ❌ | ✅ |
| Powerline / themes              | ❌ | ❌ | ✅ | ✅ |

This project prioritizes **zero-dependency**, **single-file hackability**, and **cross-platform parity**.

## Troubleshooting

<details>
<summary><b>Status line doesn't appear after install</b></summary>

- Restart Claude Code — settings reload on the next interaction
- Verify the script is executable: `ls -la ~/.claude/statusline.sh`
- Run `claude --debug` to see any stderr from the status line command
- On Windows: the `command` in `settings.json` must use a **native** Windows path (`C:/Users/…`), not a Git Bash path (`/c/Users/…`). The installer handles this automatically via `cygpath`.
</details>

<details>
<summary><b>Rate-limit rows don't appear</b></summary>

The `rate_limits` object is only populated for **Claude.ai Pro/Max subscribers** after the first API response in a session. Free users will only ever see Line 1. This is a Claude Code design choice, not a bug in this project.
</details>

<details>
<summary><b>Emojis render as boxes or tofu</b></summary>

- Windows: install [Cascadia Code](https://github.com/microsoft/cascadia-code) or a [Nerd Font](https://www.nerdfonts.com/) that includes emoji glyphs
- Ensure your terminal is set to UTF-8 output
- Or set `CLAUDE_STATUSLINE_ASCII=1` to disable emoji entirely
</details>

<details>
<summary><b>Gradient bar shows as flat color</b></summary>

Your terminal doesn't advertise 24-bit color support via `$COLORTERM`. Set it manually:
```bash
export COLORTERM=truecolor
```
Or use `CLAUDE_STATUSLINE_NERDFONT=1` / default emoji mode — both still look great with threshold colors.
</details>

<details>
<summary><b>Dirty indicator is wrong / stale</b></summary>

Git status is cached 5 seconds per session (file at `$TMPDIR/cc-statusline-git-<session_id>`). Delete that file to force a refresh, or wait 5 seconds for the next invocation.
</details>

<details>
<summary><b>Context percentage shows 0% at session start</b></summary>

That's correct — `context_window.used_percentage` is `null` until the first API response lands. After the first message it populates and updates on every turn.
</details>

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for the full release history. Latest highlights:

- **v1.1.0** — Three-line layout, truecolor gradient, rate limits, dirty branch, lines diff, ENV-driven theming
- **v1.0.0** — Initial two-line release

## Contributing

PRs and issues very welcome. A few ideas on the wishlist:

- [ ] PowerShell port for non-Git-Bash Windows users
- [ ] Session name display when set via `/rename`
- [ ] Agent-active indicator when `agent.name` is present
- [ ] Worktree badge when `workspace.git_worktree` is set
- [ ] More theme presets (Dracula / Solarized / Nord gradient stops)

Before submitting, please test on at least one OS:

```bash
bash install.sh
bash install.sh --uninstall
```

## Credits

Inspired by the official [Claude Code status line documentation](https://code.claude.com/docs/en/statusline) and these excellent community projects:

- [`kamranahmedse/claude-statusline`](https://github.com/kamranahmedse/claude-statusline) — rate-limit dashboard layout
- [`sirmalloc/ccstatusline`](https://github.com/sirmalloc/ccstatusline) — widget architecture & token metrics
- [`kcchien/claude-code-statusline`](https://github.com/kcchien/claude-code-statusline) — truecolor gradient + smart hiding

## License

[MIT](./LICENSE) © manhtruong03
