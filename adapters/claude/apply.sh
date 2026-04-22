#!/usr/bin/env bash
set -euo pipefail

MARLOWE_HOME="${MARLOWE_HOME:-$HOME/.marlowe}"
MARLOWE_FRAMEWORK="${MARLOWE_FRAMEWORK:-$HOME/.marlowe-framework}"
DST="$HOME/.claude/CLAUDE.md"

BEGIN='<!-- marlowe:begin -->'
END='<!-- marlowe:end -->'

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
  MARLOWE_HOME="$MARLOWE_HOME" "$MARLOWE_FRAMEWORK/adapters/common/render.sh"
  printf '%s\n' "$END"
} > "$DST"

rm -f "$DST.tmp"
echo "[marlowe/claude] applied -> $DST"

SL_CMD="$MARLOWE_FRAMEWORK/adapters/claude/statusline-composite.sh"
if ! grep -Eq 'marlowe.*statusline|statusline[-.]' "$HOME/.claude/settings.json" 2>/dev/null; then
  cat <<EOF
[marlowe/claude] to enable the status line, add to ~/.claude/settings.json:

  "statusLine": { "type": "command", "command": "$SL_CMD" }

(skipped automatic edit — your settings.json has live config)
EOF
fi
