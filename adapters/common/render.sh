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
# Capture protocol

Marlowe persists cross-session context. When I give you something durable,
run the matching command yourself — don't ask first, confirm in one line after.

| I say…                                       | You run                               |
|----------------------------------------------|---------------------------------------|
| "remember X" / "don't forget X" / "note X"   | `marlowe remember "X"`                |
| "from now on X" / "always X" / "never X"     | `marlowe add preference "X"`          |
| "X means Y" / "when I say X I mean Y"        | `marlowe add lingo "X — Y"`           |
| "say X instead of Y" / "use X tone"          | `marlowe add ai-lingo "X"`            |
| "I'm working on X" / "new project: X"        | `marlowe add project "X"`             |

Rules:
- Explicit cue only — don't guess what's memory-worthy from stray mentions.
- These commands commit + push automatically; no extra step.
- `marlowe` is on your PATH.
EOF
