#!/usr/bin/env bash
set -euo pipefail

MARLOWE_FRAMEWORK="${MARLOWE_FRAMEWORK:-$HOME/.marlowe-framework}"
MARLOWE_REPO="${MARLOWE_REPO:-https://github.com/jongrjon/marlowe.git}"

PINK=$'\033[38;2;254;1;154m'
RESET=$'\033[0m'
say() { printf '%s⟡ marlowe%s %s\n' "$PINK" "$RESET" "$*"; }

# 1. Framework — clone or pull.
if [ -d "$MARLOWE_FRAMEWORK/.git" ]; then
  say "framework already at $MARLOWE_FRAMEWORK, pulling"
  git -C "$MARLOWE_FRAMEWORK" pull --ff-only
else
  say "cloning framework to $MARLOWE_FRAMEWORK"
  git clone "$MARLOWE_REPO" "$MARLOWE_FRAMEWORK"
fi

# 2. CLI on PATH.
mkdir -p "$HOME/.local/bin"
ln -sf "$MARLOWE_FRAMEWORK/bin/marlowe" "$HOME/.local/bin/marlowe"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) say "add $HOME/.local/bin to your PATH" ;;
esac

# 3. Hand off to the wizard.
exec "$MARLOWE_FRAMEWORK/bin/marlowe" init
