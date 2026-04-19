<div align="center">

# claude-code-statusline

**A focused, token-aware three-line status bar for [Claude Code](https://code.claude.com).**

Detailed token breakdown, model context size, thinking effort, git state, and Pro/Max rate limits — designed for power users who actively manage context.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)](#install)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](#)
[![Runtime](https://img.shields.io/badge/runtime-Node.js-339933?logo=nodedotjs&logoColor=white)](#)
[![Version](https://img.shields.io/badge/version-1.2.2-8A2BE2)](./CHANGELOG.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#contributing)

```text
[Opus·1M·🧠H] | 🌿 main* | 📁 OfficeOS | ⏰ 87m
ctx 268k/1M (25%) · in 1 · read 267k · new 818 · out 539
current 1% ↻ 4:31am | weekly 38% ↻ apr 20, 12:31am
```

</div>

---

## Why

Claude Code's default status line is informative but silent on what power users need most during long coding sessions: **how is my context being spent, how much is cached vs. fresh, how close am I to my rate limits, and which thinking effort am I running?**

`claude-code-statusline` surfaces all of that in three compact lines — token breakdown by type (`in` / `read` / `new` / `out`), model context window size (`1M` or `200k`), **Thinking Effort** badge, **dirty-branch indicator**, and **5-hour / 7-day rate-limit quotas** with human-friendly reset times. It installs with a single command and has **zero runtime dependencies** beyond the `node` binary that Claude Code already ships.

## Features

### Line 1 — identity snapshot

| | |
|---|---|
| 🎯 **Model + context + effort badge** | `[Opus·1M·🧠H]` — model name, context window size (`1M` / `200k`), and Thinking Effort label (`Mx`/`XH`/`H`/`Md`/`L`) all in one compact bracket |
| 🌿 **Dirty branch indicator** | `main*` in red when uncommitted changes are detected |
| 📁 **Project basename** | Clean `workspace.current_dir` basename, no noisy full paths |
| ⏰ **Elapsed time** | Minute-resolution — `87m` or `2h 15m`, never seconds |

### Line 2 — token breakdown

Granular view of the four token types Claude Code reports so you can see **what's filling your context**:

| Segment | Source field | Meaning |
|---|---|---|
| `ctx 120k/1M (42%)` | derived | Total context-counting tokens / window size / percent |
| `in 58k`   | `current_usage.input_tokens`                | Fresh input this turn |
| `read 60k` | `current_usage.cache_read_input_tokens`     | Read from prompt cache (cheap) |
| `new 2k`   | `current_usage.cache_creation_input_tokens` | Written to prompt cache (one-time cost, reusable) |
| `out 4k`   | `current_usage.output_tokens`               | Generated output (doesn't count toward context) |

If `read` dominates, caching is working well. If `new` is high, Claude is building fresh cache entries. Both `read` and `new` count toward your 200k/1M context budget alongside fresh `in` tokens.

### Line 3 — rate-limit dashboard (Pro/Max only)

| | |
|---|---|
| 🕐 **5-hour rolling window** | `current 28% ↻ 7:00pm` — percentage + reset time |
| 📆 **7-day rolling window**  | `weekly 79% ↻ mar 10, 10:00am` — percentage + reset time |
| ⏱ **Smart reset formatting** | Same-day → `7:00pm`, other days → `mar 10, 10:00am` |
| 👻 **Auto-hide for free users** | Line 3 vanishes entirely when `rate_limits` is absent |

### Engineering

| | |
|---|---|
| ⚡ **Fast** | Typical runtime ~50ms — single `node` pass for parsing, formatting, and settings.json read |
| 🪶 **Zero dependencies** | No `jq`, no `python`, no `git` required on `PATH` — only `node` (bundled with Claude Code) |
| 🔁 **Git caching** | `git status --porcelain` cached 5s per session to avoid lag on big repos |
| 🛟 **Graceful fallback** | Reads `.git/HEAD` directly if `git` is missing |
| 🎛 **ENV-driven theming** | Swap between emoji / Nerd Font / pure ASCII with one environment variable |

## Preview

### Active Pro/Max session, healthy context
```
[Opus·1M·🧠H] | 🌿 main* | 📁 OfficeOS | ⏰ 87m
ctx 268k/1M (25%) · in 1 · read 267k · new 818 · out 539
current 1% ↻ 4:31am | weekly 38% ↻ apr 20, 12:31am
```

### Fresh session (before first API call)
```
[Opus·1M·🧠H] | 🌿 main | 📁 my-app | ⏰ 0m
ctx 0/1M (0%) · awaiting first response
```

### Free tier, 200k context, cache-heavy turn
```
[Sonnet·200k·🧠M] | 🌿 main* | 📁 my-app | ⏰ 1m
ctx 170k/200k (85%) · in 120k · read 50k · out 3k
```

### Critical context, long session, cache working well
```
[Opus·1M·🧠H] | 🌿 feature/auth* | 📁 core | ⏰ 45m
ctx 950k/1M (95%) · in 15k · read 920k · new 15k · out 8k
current 92% ↻ 3:15pm | weekly 71% ↻ apr 21, 9:00am
```
*Interpretation: 95% context full, but mostly `read` (cached) so most turns are cheap.*

### ASCII-only mode (CI / limited terminals)
```
[Opus·1M·[E]H] | [B] main* | [D] OfficeOS | [T] 87m
ctx 120k/1M (42%) · in 58k · read 60k · new 2k · out 4k
current 28% -> 7:00pm | weekly 79% -> mar 10, 10:00am
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
| `CLAUDE_STATUSLINE_ASCII=1` | Plain ASCII mode — no emoji, no Unicode characters |
| `CLAUDE_STATUSLINE_NERDFONT=1` | Swap emoji icons for [Nerd Font](https://www.nerdfonts.com/) glyphs |

Thinking Effort is read from `~/.claude/settings.json` — either the top-level `effortLevel` key (current Claude Code format) or `env.CLAUDE_CODE_EFFORT_LEVEL` (legacy):

```json
{
  "effortLevel": "high"
}
```

Valid values:

| Value (text or numeric) | Badge | Color |
|---|---|---|
| `max` or `6` | `Mx` | red |
| `xhigh` or `5` | `XH` | bold magenta |
| `high` or `4` | `H` | magenta |
| `medium` or `3` | `Md` | yellow |
| `low` or `2` | `L` | gray |
| `none`, `1`, or absent | *(hidden)* | — |

Both numeric and text forms are accepted.

**Per-model support:**

| Model | Supported levels |
|---|---|
| **Opus** | low, medium, high, **xhigh**, max |
| **Sonnet** | low, medium, high, max *(no xhigh — if stored, collapses to `Mx`)* |
| **Haiku** | *(no effort setting — badge hidden)* |

> ⚠️ **Session-only `/effort max` limitation.** Claude Code's `/effort max` command sets effort *for the current session only* and does **not** write to `settings.json`. The statusline can only display effort that is persisted to `settings.json` — session-only overrides are invisible to any status line command. This is a Claude Code API limitation, not a bug in this project.

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

- **Context % thresholds** — `<70%` green, `70–89%` yellow, `≥90%` red (controls `ctx` number and percent color)
- **Rate-limit thresholds** — same `<70/70–89/≥90` split via `rl_color()`
- **Thinking Effort colors** — `high` magenta, `medium` yellow, `low` dim
- **Icon set** — `I_DIR`, `I_BRANCH`, `I_TIME`, `I_RESET`, `I_THINK` swapped per mode

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

| JSON path                                              | Rendered as                            |
|--------------------------------------------------------|----------------------------------------|
| `model.display_name`                                   | `Opus` (first word) inside cyan badge  |
| `context_window.context_window_size`                   | `·1M` / `·200k` inside badge           |
| `~/.claude/settings.json` → `env.CLAUDE_CODE_EFFORT_LEVEL` | `·🧠Mx` / `·🧠XH` / `·🧠H` / `·🧠Md` / `·🧠L` inside badge |
| `context_window.used_percentage`                       | `(25%)` inside Line 2                  |
| `context_window.current_usage.input_tokens`            | `in 1`                                 |
| `context_window.current_usage.cache_read_input_tokens` | `read 267k`                            |
| `context_window.current_usage.cache_creation_input_tokens` | `new 818`                          |
| `context_window.current_usage.output_tokens`           | `out 539`                              |
| `workspace.current_dir`                                | `📁 OfficeOS` (basename only)          |
| `cost.total_duration_ms`                               | `⏰ 87m` / `⏰ 2h 15m` (minute only)   |
| `rate_limits.five_hour.used_percentage` + `resets_at`  | `current 1% ↻ 4:31am`                  |
| `rate_limits.seven_day.used_percentage` + `resets_at`  | `weekly 38% ↻ apr 20, 12:31am`         |
| *(from `.git/HEAD` + `git status --porcelain`)*        | `🌿 main*` (dirty-aware, 5s cached)    |

Full JSON schema in the [official status line docs](https://code.claude.com/docs/en/statusline#available-data).

## Comparison with similar projects

| | this repo | [kamranahmedse](https://github.com/kamranahmedse/claude-statusline) | [ccstatusline](https://github.com/sirmalloc/ccstatusline) | [kcchien](https://github.com/kcchien/claude-code-statusline) |
|---|:---:|:---:|:---:|:---:|
| Token breakdown (in/read/new/out) | ✅ | ❌ | ✅ | ❌ |
| Model context size badge        | ✅ | ❌ | ✅ | ❌ |
| Thinking Effort display         | ✅ | ❌ | ✅ | ❌ |
| Rate-limit dashboard            | ✅ | ✅ | ✅ | ✅ |
| Dirty branch indicator          | ✅ | ✅ | ✅ | ✅ |
| Human reset time (`4:31am`)     | ✅ | ✅ | ❌ | ❌ |
| Cross-platform installer        | ✅ | ✅ | ✅ | ❌ |
| Zero runtime deps (no jq/python)| ✅ | ❌ | ❌ | ❌ |
| Single-file readable bash       | ✅ | ❌ | ❌ | ✅ |
| Powerline / themes              | ❌ | ❌ | ✅ | ✅ |

This project prioritizes **token-awareness**, **zero-dependency**, **single-file hackability**, and **cross-platform parity**.

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
<summary><b>Thinking Effort doesn't show</b></summary>

- The effort field is read from `~/.claude/settings.json` — either the top-level `effortLevel` key or `env.CLAUDE_CODE_EFFORT_LEVEL`. Both text (`"high"`, `"medium"`, `"low"`, `"xhigh"`, `"max"`) and numeric (`"4"`, `"5"`, `"6"`) values are accepted.
- On **Haiku** the badge is always hidden (Haiku has no thinking effort setting).
- On **Sonnet**, any stored `"xhigh"` collapses to `Mx` (Sonnet doesn't have a distinct `xhigh` level).
- **`/effort max` is session-only** — Claude Code does not write it to `settings.json`, so the statusline cannot detect it. To see `Mx` in the badge, set effort to `max` via the Settings UI (which writes to the file) rather than the session command.
</details>

<details>
<summary><b>Line 2 shows "awaiting first response"</b></summary>

That's the pre-first-call placeholder. `context_window.current_usage` is `null` in every fresh session until Claude responds to the first message. Once the first assistant message returns, Line 2 fills in with actual token counts.
</details>

<details>
<summary><b>Dirty indicator is wrong / stale</b></summary>

Git status is cached 5 seconds per session (file at `$TMPDIR/cc-statusline-git-<session_id>`). Delete that file to force a refresh, or wait 5 seconds for the next invocation.
</details>

<details>
<summary><b>Token numbers look different from <code>/context</code></b></summary>

This project uses `context_window.current_usage` from the most recent API call. The `/context` command runs a separate calculation. Small differences can occur around turn boundaries — both numbers converge on the next assistant response.
</details>

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for the full release history. Latest highlights:

- **v1.2.2** — Bug fixes: Line 3 field-shift (IFS tab collapse), numeric effort support, `effortLevel` top-level key, new `xhigh`/`max` levels, `medium`→`Md` disambiguation, model-aware effort normalization (Haiku hidden, Sonnet `xhigh`→`Mx`)
- **v1.2.1** — Compact refinements: effort shortened to 1-letter initial, lines diff removed, minute-only duration, color hierarchy rebalance (gray separators, bold primary numbers)
- **v1.2.0** — Token-detail redesign: breakdown (in/read/new/out), model context size badge, Thinking Effort, rate limits combined on one line; removed progress bar & cost
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
