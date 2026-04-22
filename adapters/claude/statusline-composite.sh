#!/usr/bin/env bash
# Composite statusline: PAI's output + Marlowe's, joined on one line.
set -u

PAI_SL="${PAI_DIR:-$HOME/.claude}/statusline-command.sh"
MARLOWE_SL="$(dirname "$0")/statusline.sh"

pai_out=""
[ -x "$PAI_SL" ] && pai_out="$("$PAI_SL" 2>/dev/null || true)"

marlowe_out=""
[ -x "$MARLOWE_SL" ] && marlowe_out="$("$MARLOWE_SL" 2>/dev/null || true)"

if [ -n "$pai_out" ] && [ -n "$marlowe_out" ]; then
  printf '%s  %s' "$pai_out" "$marlowe_out"
else
  printf '%s%s' "$pai_out" "$marlowe_out"
fi
