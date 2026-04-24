# Changelog

All notable changes to this project. Format loosely follows [Keep a Changelog](https://keepachangelog.com).

## [0.10.0] — 2026-04-24

### Added
- **Rear-view capture** — `marlowe draft "<fact>"` queues candidates to a gitignored `drafts.md`; `marlowe review [--yes]` opens them in `$EDITOR` plus AI-proposed bullets from recent activities, survivors promote to `memory.md`.
- Capture protocol extended with a draft clause (AI may proactively call `draft`, max 3/session, on dead ends / implicit preferences / surprising findings).
- `drafts.md` auto-added to `~/.marlowe/.gitignore` by `marlowe wire`.

### Fixed
- `grep -c ... || echo 0` double-stamped "0" on no-match (grep outputs "0" and exits 1, triggering the fallback). Replaced with a `grep -q` gate pattern that doesn't mix stdout with fallback value.

## [0.9.0] — 2026-04-24

### Added
- Bats test suite under `tests/` — 22 tests across 6 files, fully isolated via throwaway `HOME` / `MARLOWE_HOME` / `GIT_CONFIG_GLOBAL` per test.

### Fixed
- `cmd_save` / `cmd_sync` adapter loop returned non-zero on fresh installs (no tool dirs) — poisoned `set -e` and silently broke every write-side command. Appended `|| true` to each loop body. Caught by the new test suite before it hit production.

## [0.8.1] — 2026-04-24

### Added
- Explicit pointer protocol in the rendered `# Projects` block — tells the AI to read the pointed `CLAUDE.md` / `AGENTS.md` for depth when asked about a project.
- `marlowe project remove <name>`, `marlowe project brief <name> <text>`, `marlowe project activate <name>` / `--clear`.

## [0.8.0] — 2026-04-24

### Added
- **A2 projects schema**: `~/.marlowe/projects.md`, pipe-separated, human-editable, pure-bash parseable (no `yq`/`jq` dep).
- Adapter render: one pointer line per project plus an 80-char brief + `[ACTIVE]` flag for the currently-active project (longest-path `$PWD` match).
- `marlowe project add [--from-cwd] | list | active`.
- `marlowe doctor` gained a 4 KiB soft budget check for `memory.md`.

### Changed
- `templates/preferences.md` dropped the old `## Projects I'm working on` section — that role moved to `projects.md`.

## [0.7.1] — 2026-04-24

### Added
- `marlowe doctor` — environment / install diagnostic (8 checks, critical-vs-warning split, `✓/·/!` + remediation hints).
- `marlowe distill --if-over N` — threshold flag for cron-safe usage.
- Telemetry counters at `~/.marlowe/.counters` (gitignored), bumped on `add`/`remember`/`activity`/`distill`. Top-3 counters shown in `marlowe status`.

## [0.7.0] — 2026-04-24

### Added
- **Automated capture (B1 + B2 + B3):**
  - `shell/marlowe.sh` — bash/zsh hook logging the first time you enter any git repo in a shell session.
  - `hooks/post-commit` — global git hook logging every commit across every repo. Installed via `core.hooksPath`.
  - `marlowe distill` — opt-in LLM pass (via `claude -p`) compressing `activities.md` into durable memory bullets.
- `marlowe activity <msg>` — fast, lockless append (atomic single-line writes).
- `marlowe wire [shell-rc]` — idempotent installer for the above.
- `activities.md` + `activities.md.last` gitignored by design (raw log is per-machine; only distilled facts cross the git boundary).

## [0.6.3] — 2026-04-22

### Changed
- **Token-efficiency pass.** Capture protocol rewritten ~45% smaller (712 B → 388 B). `marlowe status` now reports byte count of each adapter's `marlowe:begin..end` block, with soft (>8 KiB) and hard (>32 KiB) warning markers.

## [0.6.2] — 2026-04-22

### Added
- **Intra-host lock** — `_with_lock` wraps all write-side commands (`add`/`edit`/`remember`/`save`/`sync`/`apply`/`distill`/`review`) via `flock -w 10`. Lockfile at `$MARLOWE_HOME/.git/marlowe.lock` (inside `.git`, ignored for free). Dispatcher-level locking avoids self-deadlock when commands chain internally.

## [0.6.1] — 2026-04-22

### Added
- Cursor adapter: auto-copy rendered rules to clipboard (`wl-copy` / `xclip` / `xsel` / `pbcopy`, whichever is available).
- Codex adapter: apply-time hint about `sandbox_mode` in `~/.codex/config.toml`.
- `marlowe lint`: drift check flagging adapted files missing the current capture protocol.

## [0.6.0] — 2026-04-22

### Added
- **Codex adapter parity** with Claude: size guard against the 32 KiB `project_doc_max_bytes` default; `marlowe status` reports byte counts for both.
- **Capture protocol** injected via `common/render.sh` into every adapted tool. Tells the AI to run `marlowe remember` / `marlowe add` itself on explicit user cues. No per-tool hooks — works on any tool that can shell out.
