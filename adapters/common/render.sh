#!/usr/bin/env bash
# Emit the combined Marlowe context to stdout: preferences.md, then memory.md
# if it exists. All three adapters source this so they stay in sync.

set -eu

MARLOWE_HOME="${MARLOWE_HOME:-$HOME/.marlowe}"
PREFS="$MARLOWE_HOME/preferences.md"
MEM="$MARLOWE_HOME/memory.md"
PROJECTS="$MARLOWE_HOME/projects.md"

[ -f "$PREFS" ] || { echo "no preferences.md at $PREFS" >&2; exit 1; }

cat "$PREFS"

if [ -f "$MEM" ]; then
  printf '\n\n'
  cat "$MEM"
fi

# Projects (A2: pointer-only per project + active-project amplification).
# Active = longest path-prefix match of $PWD against project paths.
if [ -f "$PROJECTS" ]; then
  pwd_abs="$(pwd -P 2>/dev/null || printf '')"
  active=""
  active_len=0
  while IFS='|' read -r _n _p _g _b; do
    _p="$(printf '%s' "$_p" | sed 's/^ *//;s/ *$//')"
    _p="${_p/#\~/$HOME}"
    [ -n "$_p" ] || continue
    case "$pwd_abs" in
      "$_p"|"$_p"/*)
        if [ ${#_p} -gt $active_len ]; then
          active_len=${#_p}
          active="$(printf '%s' "${_n#- }" | sed 's/^ *//;s/ *$//')"
        fi
        ;;
    esac
  done < <(grep -E '^- ' "$PROJECTS" 2>/dev/null || true)

  printf '\n\n# Projects\n\n'
  printf 'If I ask about a project below, read its `CLAUDE.md` / `AGENTS.md` at the pointed\npath before answering. Brief = summary, not full context. Active gets priority.\n\n'
  while IFS='|' read -r _n _p _g _b; do
    _n="$(printf '%s' "${_n#- }" | sed 's/^ *//;s/ *$//')"
    _p="$(printf '%s' "$_p" | sed 's/^ *//;s/ *$//')"
    _g="$(printf '%s' "$_g" | sed 's/^ *//;s/ *$//')"
    _b="$(printf '%s' "$_b" | sed 's/^ *//;s/ *$//')"
    if [ "$_n" = "$active" ]; then
      printf -- '- **%s** (%s, %s) — %s  [ACTIVE]\n' "$_n" "$_p" "$_g" "$_b"
    else
      printf -- '- %s (%s, %s)\n' "$_n" "$_p" "$_g"
    fi
  done < <(grep -E '^- ' "$PROJECTS" 2>/dev/null || true)
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
