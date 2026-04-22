# Marlowe

Portable AI context across tools. Write your preferences, lingo, and identity once — apply them to Claude Code, Codex CLI, and Cursor from a single source of truth.

## What it is

- **Public repo** (this one): the framework — adapters, installer, CLI.
- **Private repo**: your data — `preferences.md`, reusable prompts, distilled memory. You own it, you control what syncs.
- **On-disk**: `~/.marlowe/` holds the private repo clone. Adapters write into each AI tool's config dir.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/<you>/marlowe/main/install.sh | sh
```

The installer will:
1. Clone this framework to `~/.marlowe-framework/`.
2. Prompt for your private data repo URL (or help you create one).
3. Clone it to `~/.marlowe/`.
4. Run adapters for every AI tool it detects on your machine.

## Usage

```sh
marlowe init          # one-time setup
marlowe sync          # git pull the private repo, re-apply adapters
marlowe add-tool X    # enable adapter for X (claude | codex | cursor)
marlowe edit          # open preferences.md in $EDITOR
```

## Supported tools (v0.1)

| Tool        | Inject | Capture |
|-------------|--------|---------|
| Claude Code | ✅      | (later) |
| Codex CLI   | stub   | —       |
| Cursor      | stub   | —       |

## Status

v0.1 — preferences + Claude adapter only. Dogfooding before expanding.
