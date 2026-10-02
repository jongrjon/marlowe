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

# /private slash command.
mkdir -p "$HOME/.claude/commands"
cp "$MARLOWE_FRAMEWORK/adapters/claude/commands/private.md" "$HOME/.claude/commands/private.md"

# Vault hooks (no-ops until 'marlowe vault init'). Merged into settings.json
# idempotently with jq; a one-time backup is kept next to it.
SETTINGS="$HOME/.claude/settings.json"
if command -v jq >/dev/null 2>&1; then
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  BIN="$MARLOWE_FRAMEWORK/bin/marlowe"
  if jq -e . "$SETTINGS" >/dev/null 2>&1; then
    [ -f "$SETTINGS.pre-marlowe-vault" ] || cp "$SETTINGS" "$SETTINGS.pre-marlowe-vault"
    jq --arg bin "$BIN" '
      def ensure($ev; $arg):
        ($bin + " vault hook " + $arg) as $cmd
        | .hooks[$ev] = ((.hooks[$ev] // [])
            | map(.hooks |= map(select((.command // "") | test("marlowe vault hook") | not)))
            | map(select((.hooks | length) > 0))
            + [{hooks: [{type: "command", command: $cmd}]}]);
      .hooks //= {}
      | ensure("UserPromptSubmit"; "prompt")
      | ensure("Stop"; "stop")
      | ensure("SessionStart"; "start")
      | ensure("SessionEnd"; "end")
    ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "[marlowe/claude] /private command + vault hooks installed"
  else
    echo "[marlowe/claude] settings.json isn't valid JSON — skipped vault hooks"
  fi
else
  echo "[marlowe/claude] jq not found — skipped vault hooks (needed for /private)"
fi

# PAI: patch capture hooks to skip private sessions (idempotent; re-checked at
# every SessionStart by the vault hook, so PAI upgrades get re-patched).
if ls "${PAI_DIR:-$HOME/.claude}"/hooks/*.hook.ts >/dev/null 2>&1; then
  if command -v bun >/dev/null 2>&1; then
    if PAI_DIR="${PAI_DIR:-$HOME/.claude}" bun "$MARLOWE_FRAMEWORK/adapters/claude/pai/patch.ts" --quiet; then
      echo "[marlowe/claude] PAI hooks patched for private sessions"
    else
      echo "[marlowe/claude] PAI patch incomplete — run 'marlowe vault pai-patch' for details"
    fi
  else
    echo "[marlowe/claude] PAI found but bun isn't on PATH — PAI hooks not patched"
  fi
fi

SL_CMD="$MARLOWE_FRAMEWORK/adapters/claude/statusline-composite.sh"

# On Windows, Claude Code uses bash.exe as shell for all commands and auto-detects
# .sh files (prepends "bash " internally). Just emit a forward-slash path — that's
# what Claude Code needs. Backslashes get consumed as escape chars by bash -c.
if [[ "${OSTYPE:-}" == msys* ]] || [[ -n "${MSYSTEM:-}" ]] || [[ -n "${WINDIR:-}" ]]; then
  if command -v cygpath >/dev/null 2>&1; then
    SL_FULL_CMD=$(cygpath -w "$SL_CMD" 2>/dev/null | tr '\\' '/')
  else
    # Convert POSIX path to Windows forward-slash path manually
    SL_FULL_CMD=$(echo "$SL_CMD" | sed 's|^/\([a-zA-Z]\)/|\1:/|')
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
