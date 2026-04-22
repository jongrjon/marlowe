#!/usr/bin/env bash
set -euo pipefail

MARLOWE_HOME="${MARLOWE_HOME:-$HOME/.marlowe}"
MARLOWE_FRAMEWORK="${MARLOWE_FRAMEWORK:-$HOME/.marlowe-framework}"

say() { printf '\033[1;34m[marlowe]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[marlowe]\033[0m %s\n' "$*" >&2; exit 1; }

# 1. Framework — clone or update.
if [ -d "$MARLOWE_FRAMEWORK/.git" ]; then
  say "framework already at $MARLOWE_FRAMEWORK, pulling"
  git -C "$MARLOWE_FRAMEWORK" pull --ff-only
else
  : "${MARLOWE_REPO:?set MARLOWE_REPO=https://github.com/<you>/marlowe.git}"
  say "cloning framework to $MARLOWE_FRAMEWORK"
  git clone "$MARLOWE_REPO" "$MARLOWE_FRAMEWORK"
fi

# 2. Private data repo — clone if missing.
if [ ! -d "$MARLOWE_HOME/.git" ]; then
  read -rp "Private data repo URL (blank to start empty): " data_url
  mkdir -p "$MARLOWE_HOME"
  if [ -n "$data_url" ]; then
    git clone "$data_url" "$MARLOWE_HOME"
  else
    git -C "$MARLOWE_HOME" init -q
    cp "$MARLOWE_FRAMEWORK/templates/preferences.md" "$MARLOWE_HOME/preferences.md"
    say "started empty private repo at $MARLOWE_HOME — push to a private remote when ready"
  fi
fi

# 3. Put CLI on PATH.
ln -sf "$MARLOWE_FRAMEWORK/bin/marlowe" "$HOME/.local/bin/marlowe" 2>/dev/null \
  || say "add $MARLOWE_FRAMEWORK/bin to your PATH"

# 4. Run adapters that apply (detect installed tools).
[ -d "$HOME/.claude" ] && "$MARLOWE_FRAMEWORK/adapters/claude/apply.sh"
[ -d "$HOME/.codex" ]  && "$MARLOWE_FRAMEWORK/adapters/codex/apply.sh"
[ -d "$HOME/.cursor" ] && "$MARLOWE_FRAMEWORK/adapters/cursor/apply.sh"

say "done. edit $MARLOWE_HOME/preferences.md and run 'marlowe sync' to reapply."
