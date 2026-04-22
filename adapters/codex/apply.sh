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

# Capture protocol needs Codex to execute `marlowe remember` / `marlowe add`
# itself. Codex's default sandbox blocks writes outside the current workspace,
# which breaks writes to ~/.marlowe/. Hint at the config if it's not set.
CONFIG="$HOME/.codex/config.toml"
if [ ! -f "$CONFIG" ] || ! grep -Eq '^[[:space:]]*sandbox_mode[[:space:]]*=' "$CONFIG" 2>/dev/null; then
  cat <<EOF
[marlowe/codex] hint: capture protocol needs Codex to run shell commands that
  write outside the workspace (marlowe remember / add touch ~/.marlowe/).
  Default sandbox blocks this. In ~/.codex/config.toml consider:

    sandbox_mode = "workspace-write"
    [sandbox_workspace_write]
    writable_roots = ["~/.marlowe"]
EOF
fi
