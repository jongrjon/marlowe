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

printf '\n\n'
cat <<'EOF'
# Capture

On explicit cues, run the command yourself (one-line confirm, no ask):
- "remember X" / "note X"       → `marlowe remember "X"`
- "from now on X" / "always X"  → `marlowe add preference "X"`
- "X means Y"                   → `marlowe add lingo "X — Y"`
- "say X / use X tone"          → `marlowe add ai-lingo "X"`
- "working on X"                → `marlowe add project "X"`

Explicit cue only. `marlowe` is on PATH; auto-commits.
EOF
