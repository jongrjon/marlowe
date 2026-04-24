# Marlowe

Portable AI context across tools. Write your preferences, lingo, and identity once — apply them to Claude Code, Codex CLI, and Cursor from a single source of truth.

## What it is

- **Public repo** (this one): the framework — adapters, installer, CLI.
- **Private repo**: your data — `preferences.md`, reusable prompts, distilled memory. You own it, you control what syncs.
- **On-disk**: `~/.marlowe/` holds the private repo clone. Adapters write into each AI tool's config dir.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jongrjon/marlowe/main/install.sh | sh
```

The installer clones the framework to `~/.marlowe-framework/`, puts `marlowe` on your PATH, and hands off to `marlowe init`.

## `marlowe init` — interactive wizard

```
⟡ marlowe init

1/4  Identity
  your name [jhek]: Jón Helgi
  assistant name [Marlowe]: BlíBlú

2/4  Data repo
    (a) clone existing URL
    (b) create new private GitHub repo via 'gh'
    (c) start empty (no remote — add one later)
  choice (a/b/c) [c]: b
  new repo slug (e.g. you/marlowe-data): jongrjon/marlowe-data

3/4  Tools
  apply claude adapter (~/.claude detected) [Y/n]: y
  apply codex  adapter (~/.codex  detected) [Y/n]: y
  apply cursor adapter (~/.cursor detected) [Y/n]: y

4/4  Summary
  identity:  Jón Helgi / BlíBlú
  data repo: create jongrjon/marlowe-data (private)
  adapters:  claude codex cursor
  proceed [Y/n]: y
```

## Usage

```sh
marlowe init [--force]        first-time setup
marlowe status                one-glance health check
marlowe add <type> <text…>    append a structured entry (auto-commits + pushes)
                              types: lingo | ai-lingo | preference | project
marlowe edit                  open preferences.md in $EDITOR; offers auto-save
marlowe remember <fact…>      append a dated bullet to memory.md (auto-commits + pushes)
marlowe save [-m <msg>]       commit + push + re-apply (no-op if clean)
marlowe lint                  validate preferences.md
marlowe sync                  pull from origin, re-apply adapters
marlowe apply <tool>          re-run one adapter (claude | codex | cursor)
marlowe wire [shell-rc]       install shell + git post-commit hooks (idempotent)
marlowe activity <msg>        fast, lockless append to local activities.md
marlowe distill               LLM-compress activities.md -> memory.md bullets
```

## Push policy — when does Marlowe commit / push?

> **Commit on every user action. Push opportunistically. Surface drift via `status`.**

| Trigger                  | Commit | Push |
|--------------------------|--------|------|
| `marlowe add …`          | ✓      | ✓    |
| `marlowe edit` → save    | ask    | ask  |
| `marlowe save`           | ✓      | ✓    |
| `marlowe sync`           | —      | —    |

Design notes:
- **Local commit is durable immediately** — survives reboot as soon as the command returns, because git objects are fsync'd to disk.
- **Push is best-effort** — if you're offline, the next `marlowe add` / `edit` / `save` retries automatically. `status` shows `ahead N` when you have unpushed commits.
- **No timers / cron by default** — events, not clocks.

### Optional: shell-exit safety net

If you want a belt-and-braces retry when you log out of a shell (useful on laptops that sleep often), add this to `~/.bashrc` or `~/.zshrc`:

```sh
trap 'marlowe save --if-dirty --quiet 2>/dev/null' EXIT
```

`marlowe save` is a no-op when the working tree is clean, so the trap is cheap.

## Supported tools

| Tool        | Inject | Capture        |
|-------------|--------|----------------|
| Claude Code | ✅     | ✅ via protocol |
| Codex CLI   | ✅     | ✅ via protocol |
| Cursor      | stub   | —              |

## Capture protocol

Inject is half the loop — capture is the other half. Every adapter injects a
small block that tells the AI when to run `marlowe remember` / `marlowe add`
itself. No per-tool hooks, no daemons.

- "remember X" / "note X"       → `marlowe remember "X"`
- "from now on X" / "always X"  → `marlowe add preference "X"`
- "X means Y"                   → `marlowe add lingo "X — Y"`
- "say X / use X tone"          → `marlowe add ai-lingo "X"`
- "working on X"                → `marlowe add project "X"`

Explicit cue only. Auto-commits + pushes. Works on any tool that can shell out.

## Automated capture (B1 + B2 + B3)

Explicit capture requires you to be alive and in-session. For crash-readiness,
Marlowe runs three always-on, zero-token taps that feed a raw, **gitignored**
`~/.marlowe/activities.md` log. Nothing crosses the git boundary until you
explicitly run `marlowe distill`.

- **B1 — shell entry hook.** Logs the first time you `cd` into any git repo
  in a shell session. Installed via `marlowe wire`, appended to `~/.bashrc`
  (or `~/.zshrc`). Runs async so the prompt never waits.
- **B2 — git post-commit hook.** Every commit on any repo becomes one activity
  line: `commit <repo>@<sha>: <subject>`. Installed globally via
  `core.hooksPath`. Silent on failure; never blocks a commit.
- **B3 — `marlowe distill`.** Opt-in LLM pass (uses local `claude` CLI) that
  compresses N raw activity lines into 1-3 durable bullets, promotes them to
  `memory.md`, and archives the raw log to `activities.md.last` (also
  gitignored). Run it weekly, or when `marlowe status` flags >50 lines.

**Why gitignored?** Raw activities are noisy and per-machine. Only distilled
facts are worth the perpetual per-session token cost in every adapted tool.

Setup:
```sh
marlowe wire              # one-time; idempotent
source ~/.bashrc          # or open a new shell
marlowe distill           # when the log builds up
```

## Status

v0.6 — inject working on Claude + Codex, capture protocol shipped across both.
Cursor adapter still stub-only.
