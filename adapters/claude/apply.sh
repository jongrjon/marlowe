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

# On Windows (Git Bash / MSYS2), Claude Code cannot exec .sh files directly.
# The command must be prefixed with an explicit bash.exe path.
if [[ "${OSTYPE:-}" == msys* ]] || [[ -n "${MSYSTEM:-}" ]] || [[ -n "${WINDIR:-}" ]]; then
  if command -v cygpath >/dev/null 2>&1; then
    _bash_win=$(cygpath -w "${BASH:-/usr/bin/bash}" 2>/dev/null | tr '\\' '/')
    _sl_win=$(cygpath -w "$SL_CMD" 2>/dev/null | tr '\\' '/')
    SL_FULL_CMD="$_bash_win $_sl_win"
  else
    SL_FULL_CMD="C:/Program Files/Git/bin/bash.exe $SL_CMD"
  fi
else
  SL_FULL_CMD="$SL_CMD"
fi

if ! grep -Eq 'marlowe.*statusline|statusline[-.]' "$HOME/.claude/settings.json" 2>/dev/null; then
  cat <<EOF
[marlowe/claude] to enable the status line, add to ~/.claude/settings.json:

  "statusLine": { "type": "command", "command": "$SL_FULL_CMD" }

(skipped automatic edit — your settings.json has live config)
EOF
fi
