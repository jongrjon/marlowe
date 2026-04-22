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
marlowe init [--force]   first-time setup
marlowe sync             pull private repo, re-apply every detected adapter
marlowe edit             open preferences.md in $EDITOR
marlowe apply <tool>     re-run one adapter (claude | codex | cursor)
```

## Supported tools (v0.1)

| Tool        | Inject | Capture |
|-------------|--------|---------|
| Claude Code | ✅      | (later) |
| Codex CLI   | stub   | —       |
| Cursor      | stub   | —       |

## Status

v0.1 — preferences + Claude adapter only. Dogfooding before expanding.
