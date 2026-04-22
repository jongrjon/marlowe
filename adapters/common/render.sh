#!/usr/bin/env bash
# Emit the combined Marlowe context to stdout: preferences.md, then memory.md
# if it exists. All three adapters source this so they stay in sync.

set -eu

MARLOWE_HOME="${MARLOWE_HOME:-$HOME/.marlowe}"
PREFS="$MARLOWE_HOME/preferences.md"
MEM="$MARLOWE_HOME/memory.md"

[ -f "$PREFS" ] || { echo "no preferences.md at $PREFS" >&2; exit 1; }

cat "$PREFS"

if [ -f "$MEM" ]; then
  printf '\n\n'
  cat "$MEM"
fi
