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
marlowe doctor                environment / install diagnostic
marlowe wire [shell-rc]       install shell + git post-commit hooks (idempotent)
marlowe activity <msg>        fast, lockless append to local activities.md
marlowe distill [--if-over N] LLM-compress activities.md -> memory.md bullets
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

## Rear-view capture (drafts + review)

Explicit cues only catch what you *know* matters. Often you don't realize
until after the fact what was important — the turn that was a dead end,
the implicit preference revealed by frustration, the surprising finding.

Marlowe handles this with a **draft queue**:

- **AI proactively calls `marlowe draft "<fact>"`** (max 3/session) when it
  notices these patterns — via an extension to the capture protocol.
- **Drafts are gitignored** — they live in `~/.marlowe/drafts.md`, local-only.
- **`marlowe review`** opens a temp file in `$EDITOR` with existing drafts
  plus fresh AI-proposed bullets from recent activity. Delete lines you
  don't want; save to promote the rest to `memory.md`.

This creates three capture modes that compose:

| You... | → runs | lives in |
|--------|--------|----------|
| explicitly flag (`"remember X"`)      | `marlowe remember` | memory.md (direct) |
| pass through AI's observation          | `marlowe draft`    | drafts.md → review → memory.md |
| realize in retrospect (`marlowe review`) | review proposes from activity log | memory.md (after approval) |

Setup:
```sh
marlowe wire              # one-time; idempotent
source ~/.bashrc          # or open a new shell
marlowe distill           # when the log builds up
```

## Private vault (`/private`)

For context that must travel between machines and accounts but never sit in
plaintext: an encrypted state file in your data repo, plus cleanup of
everything a private Claude Code session leaves behind.

```sh
marlowe vault init          # once: makes a GPG keypair (passphrase dialog), commits only ciphertext
marlowe apply claude        # installs /private + the four vault hooks
```

In Claude Code, `/private` starts a session and `/private end` seals it.

| Piece | Where | In git? |
|---|---|---|
| `state.md.gpg`: the only thing a session loads | `~/.marlowe/vault/` | yes (ciphertext) |
| `pubkey.gpg` / `seckey.gpg` (passphrase-protected) | `~/.marlowe/vault/` | yes |
| Decrypted working copy | `/dev/shm/marlowe-vault-<uid>/` (RAM) | never |
| Per-turn transcript checkpoints | `~/.private/live/` | never |
| Swept session archives | `~/.private/sessions/` | never |

**Lifecycle**
- **Start:** the `UserPromptSubmit` hook sees `/private` and registers the session
  in `.vault-open` (gitignored). Capture hooks that honour the marker skip it.
  `vault open` pulls, decrypts `state.md` into RAM and prints its path.
- **During:** the `Stop` hook checkpoints after every reply. The state file is
  encrypted if it changed, the transcript is encrypted to `~/.private/live/`, and
  the ciphertext is pushed at most every 15 minutes. Encrypting uses the public
  key, so it never needs the passphrase.
- **`/private end`:** the AI updates the state file, then `vault seal` commits
  `vault: seal` and shreds the RAM copy.
- **Exit:** the `SessionEnd` hook checkpoints, then a detached process sweeps the
  session a few seconds later. The sweep encrypts its transcript, subagent files,
  `history.jsonl` lines, paste-cache entries and session-env into
  `~/.private/sessions/`, then removes them.
- **Terminal closed, crash or `kill -9`:** the next session's `SessionStart` hook
  (or `marlowe vault recover`) finds the dead PID and does the same sweep. The
  statusline shows `🔒 private` or `⚠ private session not cleaned`.

**New machine**
1. Prerequisites: `git`, `gpg` 2.1.14+, `jq`, `tar`, `shred`, a pinentry, and
   access to your data repo.
2. Run `install.sh`. The wizard clones the data repo.
3. Run `marlowe apply claude` once Claude Code has created `~/.claude`.
4. In Claude Code, run `/private`. The first time, it imports the key from
   `vault/seckey.gpg`, which asks for your passphrase.
5. Check with `marlowe vault status`.

Open the vault on one machine at a time. Run `/private end` before switching,
because the encrypted state can't be merged.

**PAI.** If PAI's hooks are present, `marlowe apply claude` patches its capture
hooks to skip private sessions (`marlowe vault pai-patch`, which needs `bun`).
- **What changes:**
  - each capture hook gains an import and a guard line, using `hooks/lib/private.ts`
  - `SecurityValidator` still blocks commands, but skips its log for private sessions
  - PAI's `Inference.ts` stops saving a transcript for every inference call, in all
    sessions
- **How it applies:** insertion points are matched by pattern, not exact text.
  Every edit is checked to compile, and the original is restored if it doesn't.
  Originals are kept in `hooks.bak-marlowe-<date>/`.
- **After PAI upgrades:** every `SessionStart` checks the patch and reapplies it if
  an upgrade overwrote the hooks. This also happens on machines that don't have a
  vault yet.
- **Status:** `marlowe vault status` reports whether the patch is in place;
  `pai-patch --check` checks it without changing anything.

**Guardrails**
- `save` refuses if any non-`.gpg` file is under `vault/`.
- `remember`, `draft` and `add` refuse inside a private session.
- Vault commits never carry content.

**Limits**
- Everything said in the session still reaches the model provider.
- `shred` is best-effort on SSDs, so use full-disk encryption.
- Other hook frameworks must check `.vault-open` themselves. PAI is patched
  automatically.

## Platform support

Marlowe is a POSIX shell project. It depends on `bash` (4+), `git`, `awk`,
`sed`, `grep`, `wc`, `mktemp`, `readlink -f`, and (optionally) `flock`.
The vault also needs `gpg` (2.1.14+), `jq`, `tar` and `shred`.

| Platform | Status | Notes |
|---|---|---|
| **Linux** | ✅ Primary | Reference platform; all releases tested here |
| **Windows + WSL2** | ✅ Recommended for Windows | Identical to Linux, zero changes |
| **Windows + Git Bash** | ⚠️ Works with caveats | No `flock` by default → intra-host lock degrades to warn-and-proceed. Cursor clipboard uses `clip.exe`. Set `git config --global core.autocrlf input` so shell scripts stay LF. Install.sh symlink may need Windows developer mode enabled, or replace with a wrapper script. Claude Code `statusLine` requires an explicit `bash.exe` prefix in the command — `marlowe apply claude` generates the correct string automatically. |
| **Windows + PowerShell** | ❌ Not supported | Would require a parallel implementation. Use WSL2 or Git Bash. |
| **macOS** | ⚠️ Needs GNU coreutils | `brew install coreutils flock` — then `greadlink -f` and `flock` are available. Without GNU coreutils, `readlink -f` fails silently in some paths and `flock` absence triggers the warn-and-proceed degradation. |

### Windows setup — the 60-second path

```powershell
wsl --install -d Ubuntu   # Windows admin shell, one-time
```

Then inside the Ubuntu WSL shell, `curl … | sh` the installer exactly as on Linux. Marlowe's state lives at `\\wsl$\Ubuntu\home\<you>\.marlowe` — `marlowe apply claude` / `codex` / `cursor` writes to whichever adapter configs are visible from WSL. For Windows-native Cursor, paste the rendered rules from `\\wsl$\Ubuntu\home\<you>\.marlowe\generated\cursor-rules.md` into Cursor's User Rules panel.

## Tests

Bats test suite under `tests/`. Install bats-core, then:

```sh
bats tests/
```

Each test is isolated — runs against a throwaway `HOME` / `MARLOWE_HOME` / git
global config, so it never touches your real dotfiles or config.

## Status

v0.6 — inject working on Claude + Codex, capture protocol shipped across both.
Cursor adapter still stub-only.
