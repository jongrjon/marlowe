#!/usr/bin/env bash
set -euo pipefail

MARLOWE_HOME="${MARLOWE_HOME:-$HOME/.marlowe}"
SRC="$MARLOWE_HOME/preferences.md"
DST="$HOME/.claude/CLAUDE.md"

BEGIN='<!-- marlowe:begin -->'
END='<!-- marlowe:end -->'

[ -f "$SRC" ] || { echo "no preferences.md at $SRC" >&2; exit 1; }
mkdir -p "$(dirname "$DST")"
touch "$DST"

# Strip any previous marlowe block, then append a fresh one.
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
echo "[marlowe/claude] applied preferences.md -> $DST"

# Status line — opt-in. Print the snippet; don't auto-merge settings.json.
SL_CMD="${MARLOWE_FRAMEWORK:-$HOME/.marlowe-framework}/adapters/claude/statusline.sh"
if ! grep -q "statusline.sh" "$HOME/.claude/settings.json" 2>/dev/null; then
  cat <<EOF
[marlowe/claude] to enable the status line, add to ~/.claude/settings.json:

  "statusLine": { "type": "command", "command": "$SL_CMD" }

(skipped automatic edit — your settings.json has live config)
EOF
fi
