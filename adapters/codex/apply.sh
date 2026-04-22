#!/usr/bin/env bash
set -euo pipefail

MARLOWE_HOME="${MARLOWE_HOME:-$HOME/.marlowe}"
SRC="$MARLOWE_HOME/preferences.md"
DST="$HOME/.codex/AGENTS.md"

BEGIN='<!-- marlowe:begin -->'
END='<!-- marlowe:end -->'

[ -f "$SRC" ] || { echo "no preferences.md at $SRC" >&2; exit 1; }
mkdir -p "$(dirname "$DST")"
touch "$DST"

awk -v b="$BEGIN" -v e="$END" '
  $0 == b {skip=1; next}
  $0 == e {skip=0; next}
  !skip
' "$DST" > "$DST.tmp"

{
  cat "$DST.tmp"
  printf '\n%s\n' "$BEGIN"
  echo "<!-- managed by marlowe; edit ~/.marlowe/preferences.md instead -->"
  cat "$SRC"
  printf '%s\n' "$END"
} > "$DST"

rm -f "$DST.tmp"
echo "[marlowe/codex] applied preferences.md -> $DST"
