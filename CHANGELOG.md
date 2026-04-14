# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] — 2026-04-15

### Changed
- **Color hierarchy rebalanced** — replaced overused `\033[2m` (dim, ~50% opacity) with explicit 8-bit gray `\033[38;5;245m` for structural characters only (`|`, `·`, `↻`, `/`, `()`). Labels (`ctx`, `in`, `read`, `new`, `out`, `current`, `weekly`) and reset times are now rendered in normal weight for much better contrast on dark terminals.
- **Primary numbers emphasized** — `ctx` total, context `%`, and rate-limit `%` now rendered **bold + threshold color** to establish clear visual hierarchy over supporting detail.
- **Thinking Effort merged into the model badge** — `[Opus · 1M] | ... | 🧠 high | ...` → `[Opus·1M·🧠H] | ...`. Shaves a full segment from Line 1.
- **Thinking Effort shortened to single-letter initial** — `high` → `H` (magenta), `medium` → `M` (yellow), `low` → `L` (gray). Frees ~4 cells while preserving semantic colour.
- **Badge spacing tightened** — removed whitespace around the `·` separators inside `[…]` (was `Opus · 1M · 🧠 high`, now `Opus·1M·🧠H`). Saves 4 cells.
- **Duration format — minute-only** — `cost.total_duration_ms` now always renders at minute resolution. `<60m` → `Xm` (displays `0m` during the first minute), `≥60m` → `Xh Ym` (or `Xh` when minutes are zero). Seconds are never displayed.
- **Low effort color** — `low` effort now uses gray (245) instead of `\033[2m` dim, so it stays readable on dark terminals.

### Removed
- **Lines diff (`+150/-30`) segment** removed from Line 1. Branch segment now shows only `🌿 branch` + dirty `*`. Reduces Line 1 length substantially and avoids noise on branches with large diffs.

### Impact
- **Line 1 length**: ~92 cells → ~68 cells on a typical session (−26%). Fits comfortably in 80-column terminals even with long branch names.
- No functional dependencies changed. Still pure bash + single `node` pass.

---

## [1.2.0] — 2026-04-15

### Changed (breaking display overhaul)
- **Removed progress bar** on Line 1 — power users prefer numeric token detail over visual indicators.
- **Removed Session Cost** (`$0.08`) — focus shifted to context management, not spend tracking.
- **Line 2 is now a token breakdown** instead of a rate-limit row:
  ```
  ctx 120k/1M (42%) · in 58k · read 60k · new 2k · out 4k
  ```
  Numbers come from `context_window.current_usage.*` — sources: `input_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`, `output_tokens`.
- **Line 3 now combines both rate-limit windows** on a single row:
  ```
  current 28% ↻ 7:00pm | weekly 79% ↻ mar 10, 10:00am
  ```
  Dot bars removed for density; the text color still reflects the 70%/90% thresholds.

### Added
- **Model context window badge** — `[Opus · 1M]` or `[Sonnet · 200k]` from `context_window.context_window_size`.
- **Thinking Effort segment** — `🧠 high` / `🧠 medium` / `🧠 low` read from `~/.claude/settings.json` → `env.CLAUDE_CODE_EFFORT_LEVEL`. Segment hides when the field is absent or the file is missing.
- **Human-readable token humanization** — values render as `58k`, `1.2M`, etc.
- **"Awaiting first response" placeholder** for fresh sessions before `current_usage` is populated.

### Technical
- Added `os.homedir()` + `fs.existsSync()` checks inside the single node parse pass to load settings cross-platform.
- Output field count bumped to 19 (was 14); `read` in bash widened with the new effort and token fields.
- Script remains pure bash + one node invocation; no new runtime dependencies.

---

## [1.1.0] — 2026-04-14

### Added
- **Three-line layout**: primary status bar plus dedicated `current` (5-hour) and `weekly` (7-day) rate-limit rows with dot bars and human-readable reset times (`↻ 7:00pm` today, `↻ mar 10, 10:00am` other days).
- **True-color gradient progress bar** (24-bit) — green → yellow → red across the filled segment. Auto-detected via `$COLORTERM`, with graceful fallback to threshold-based solid colors.
- **Dirty branch indicator** — `main*` in bold red when uncommitted changes are detected.
- **Lines diff display** — `+150/-30` from `cost.total_lines_added` / `cost.total_lines_removed`. Hidden when both are zero.
- **Smart cost coloring** — dim at `$0.00`, yellow during normal spend, red when `> $10`.
- **Rate-limit reset formatting** — `7:00pm` for same-day resets, `mar 10, 10:00am` for future dates. Powered by Node's `Intl` APIs.
- **Auto-hide for free users** — rate-limit rows vanish entirely when the `rate_limits` payload is absent (Claude Code only sends it for Pro/Max subscribers).
- **ENV-driven theming**:
  - `CLAUDE_STATUSLINE_ASCII=1` — plain ASCII mode (no emoji, `#`/`-` blocks, `*`/`.` dots, `[D]`/`[B]`/`[T]` icons).
  - `CLAUDE_STATUSLINE_NERDFONT=1` — swap emoji for Nerd Font glyphs.
- **Git status caching** — 5-second cache keyed by `session_id`, stored under `$TMPDIR/cc-statusline-git-<id>`. Eliminates lag on large repos.
- **Graceful `git` fallback** — reads `.git/HEAD` directly when `git` isn't on `PATH`.
- **Safer session-id handling** — non-alphanumerics stripped from cache filenames.

### Changed
- Model display now shortens to the first word by default (`Opus 4.6 (1M context)` → `Opus`).
- Progress bar empty segment uses a dim gray `(80,80,80)` in truecolor mode for better contrast with the gradient-filled portion.
- Separator `|` is now dimmed to let colored segments stand out.
- Git branch text colored green; dirty `*` bold red for emphasis.

### Technical
- Replaced multiple `node` calls with a single consolidated parse + format pass — all field extraction, number formatting, and reset-time formatting happen in one Node invocation.
- All logic kept in pure bash for everything the shell can handle (bar rendering, color selection, git cache, final assembly).
- Typical end-to-end runtime remains **under 50ms**.

---

## [1.0.0] — 2026-04-14

### Added
- Initial public release.
- Two-line status bar rendering model, project, git branch, context window percentage, session cost, and elapsed duration.
- Portable `statusline.sh` — pure bash + `node` (no `jq`, `python`, or `git` dependency).
- Cross-platform `install.sh`:
  - Detects Windows (MINGW/MSYS/Cygwin), macOS (Darwin), and Linux.
  - Copies the script to `~/.claude/`, marks it executable on Unix.
  - Merges the `statusLine` block into `~/.claude/settings.json` without clobbering existing keys.
  - Converts Unix-style paths to native Windows paths via `cygpath -m` for Claude Code on Windows.
  - Supports `--uninstall` to remove the script and the `statusLine` block while preserving the rest of `settings.json`.
- MIT license, polished README with install/config/troubleshooting, `.gitignore`.
