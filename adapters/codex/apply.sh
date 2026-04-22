#!/usr/bin/env bash
set -euo pipefail

MARLOWE_HOME="${MARLOWE_HOME:-$HOME/.marlowe}"
MARLOWE_FRAMEWORK="${MARLOWE_FRAMEWORK:-$HOME/.marlowe-framework}"
DST="$HOME/.codex/AGENTS.md"

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
echo "[marlowe/codex] applied -> $DST"

# Size guard: Codex CLI defaults project_doc_max_bytes=32768 and silently
# truncates beyond that. Warn if we've crossed the line.
LIMIT=32768
SIZE="$(wc -c < "$DST")"
if [ "$SIZE" -gt "$LIMIT" ]; then
  cat <<EOF
[marlowe/codex] WARN: $DST is ${SIZE} bytes (> ${LIMIT} default limit).
Codex will truncate. Raise the limit in ~/.codex/config.toml:

  project_doc_max_bytes = $(( (SIZE / 1024 + 4) * 1024 ))
EOF
fi
