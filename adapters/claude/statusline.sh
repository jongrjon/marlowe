#!/usr/bin/env bash
# Claude Code statusLine command — prints one line.
# Wire via ~/.claude/settings.json:
#   "statusLine": { "type": "command", "command": "~/.marlowe-framework/adapters/claude/statusline.sh" }

set -eu
PREFS="${MARLOWE_HOME:-$HOME/.marlowe}/preferences.md"
USER_NAME="$(awk -F': *' '/^[[:space:]]*user_name:/ {print $2; exit}' "$PREFS" 2>/dev/null || true)"
USER_NAME="${USER_NAME:-you}"

# Brand: magenta (#fe019a) truecolor on "⟡ marlowe", reset, then user.
PINK=$'\033[38;2;254;1;154m'
RESET=$'\033[0m'
printf '%s⟡ marlowe%s · %s' "$PINK" "$RESET" "$USER_NAME"
