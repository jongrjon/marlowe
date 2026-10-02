# shellcheck shell=bash
# marlowe vault — encrypted private context that travels with marlowe-data.
# Sourced by bin/marlowe. See README "Private vault".
#
# Layout
#   $MARLOWE_HOME/vault/pubkey.gpg     public key (encrypt without a passphrase)
#   $MARLOWE_HOME/vault/seckey.gpg     secret key, passphrase-protected (new machines import it)
#   $MARLOWE_HOME/vault/state.md.gpg   the rolling state file (the only thing a session loads)
#   $MARLOWE_HOME/.vault-open          private sessions: "<sid>\t<pid>\t<started>\t<transcript>"
#   <ram>/marlowe-vault-<uid>/state.md decrypted working copy (/dev/shm when available)
#   $MARLOWE_PRIVATE/live/<sid>.jsonl.gpg      per-turn transcript checkpoints (local only)
#   $MARLOWE_PRIVATE/sessions/<date>-<sid>.tar.gpg   swept session archives (local only)
#
# Only *.gpg under vault/ is ever committed. Plaintext never lives in $MARLOWE_HOME.

VAULT_DIR="$MARLOWE_HOME/vault"
VAULT_MARKER="$MARLOWE_HOME/.vault-open"
VAULT_PUSHED="$MARLOWE_HOME/.vault-pushed"
VAULT_PRIVATE="${MARLOWE_PRIVATE:-$HOME/.private}"
VAULT_CLAUDE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
VAULT_PUSH_EVERY="${MARLOWE_VAULT_PUSH_EVERY:-900}"
VAULT_PROC_RE="${MARLOWE_VAULT_PROC_RE:-claude}"
VAULT_UID="Marlowe Vault <vault@marlowe.local>"

_vault_work() {
  if [ -n "${MARLOWE_VAULT_WORK:-}" ]; then printf '%s' "$MARLOWE_VAULT_WORK"; return; fi
  local base=/dev/shm
  { [ -d "$base" ] && [ -w "$base" ]; } || base="${TMPDIR:-/tmp}"
  printf '%s/marlowe-vault-%s' "$base" "$(id -u)"
}

_vault_ram_base() { dirname "$(_vault_work)"; }

_vault_shred_tree() {
  # _vault_shred_tree <path>… — overwrite files then remove. Best effort on SSDs.
  local p
  for p in "$@"; do
    [ -e "$p" ] || continue
    if [ -d "$p" ]; then
      find "$p" -type f -exec shred -u {} + 2>/dev/null || find "$p" -type f -delete
      rm -rf "$p"
    else
      shred -u "$p" 2>/dev/null || rm -f "$p"
    fi
  done
}

_vault_sum() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

_vault_encrypt() {
  # _vault_encrypt <in|-> <out> — public-key encrypt; never needs a passphrase.
  local in="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  if [ "$in" = - ]; then
    gpg --batch --yes -q --trust-model always --recipient-file "$VAULT_DIR/pubkey.gpg" -e -o "$out.tmp"
  else
    gpg --batch --yes -q --trust-model always --recipient-file "$VAULT_DIR/pubkey.gpg" -e -o "$out.tmp" "$in"
  fi && chmod 600 "$out.tmp" && mv -f "$out.tmp" "$out"
}

_vault_fpr() {
  gpg --show-keys --with-colons "$VAULT_DIR/pubkey.gpg" 2>/dev/null | awk -F: '$1=="fpr"{print $10; exit}'
}

_vault_have_secret() {
  local fpr; fpr="$(_vault_fpr)"
  [ -n "$fpr" ] && gpg --list-secret-keys "$fpr" >/dev/null 2>&1
}

_vault_require_init() {
  [ -f "$VAULT_DIR/pubkey.gpg" ] || die "no vault — run 'marlowe vault init'"
}

_vault_ensure_ignore() {
  local gi="$MARLOWE_HOME/.gitignore" line
  touch "$gi"
  for line in '.vault-open' '.vault-pushed' 'vault/*' '!vault/*.gpg'; do
    grep -qxF -- "$line" "$gi" || printf '%s\n' "$line" >> "$gi"
  done
}

# ---- session marker ---------------------------------------------------------

_vault_proc_matches() { ps -o comm= -p "$1" 2>/dev/null | grep -Eq "$VAULT_PROC_RE"; }

_vault_alive() {
  # _vault_alive <pid> [started] — pid "ended" = finished; "-" = unknown, treated
  # as live for 12h after start so an unregistered pid isn't swept mid-session.
  local pid="$1" started="${2:-}"
  case "$pid" in
    ended|"") return 1 ;;
    -) local t; t="$(date -d "$started" +%s 2>/dev/null || echo 0)"
       [ $(( $(date +%s) - t )) -lt 43200 ] ;;
    *) kill -0 "$pid" 2>/dev/null && _vault_proc_matches "$pid" ;;
  esac
}

_vault_claude_pid() {
  # Walk up from our parent to the nearest process whose name matches claude.
  local p="$PPID" i
  for i in 1 2 3 4 5 6 7 8; do
    [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null || break
    if _vault_proc_matches "$p"; then printf '%s' "$p"; return 0; fi
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
  done
  return 1
}

_vault_sessions() { [ -f "$VAULT_MARKER" ] && grep -v '^[[:space:]]*$' "$VAULT_MARKER" || true; }

_vault_field() { # _vault_field <sid> <n>
  _vault_sessions | awk -F'\t' -v s="$1" -v n="$2" '$1==s{print $n; exit}'
}

_vault_marker_put() { # <sid> <pid> <transcript>
  local sid="$1" pid="${2:--}" tr="${3:--}" started
  started="$(_vault_field "$sid" 3)"; [ -n "$started" ] || started="$(date -Iseconds)"
  [ "$tr" = - ] && tr="$(_vault_field "$sid" 4)"; [ -n "$tr" ] || tr=-
  { _vault_sessions | awk -F'\t' -v s="$sid" '$1!=s'
    printf '%s\t%s\t%s\t%s\n' "$sid" "$pid" "$started" "$tr"
  } > "$VAULT_MARKER.tmp" && mv -f "$VAULT_MARKER.tmp" "$VAULT_MARKER"
}

_vault_marker_del() {
  [ -f "$VAULT_MARKER" ] || return 0
  _vault_sessions | awk -F'\t' -v s="$1" '$1!=s' > "$VAULT_MARKER.tmp"
  mv -f "$VAULT_MARKER.tmp" "$VAULT_MARKER"
  [ -s "$VAULT_MARKER" ] || rm -f "$VAULT_MARKER"
}

_vault_current_sid() {
  # The session calling us: explicit env, else match our claude ancestor's pid.
  if [ -n "${CLAUDE_SESSION_ID:-}" ]; then printf '%s' "$CLAUDE_SESSION_ID"; return; fi
  local pid; pid="$(_vault_claude_pid)" || return 1
  _vault_sessions | awk -F'\t' -v p="$pid" '$2==p{print $1; exit}'
}

_vault_caller_private() { local s; s="$(_vault_current_sid 2>/dev/null)"; [ -n "$s" ]; }

_vault_find_transcript() {
  find "$VAULT_CLAUDE/projects" -maxdepth 2 -type f -name "$1.jsonl" 2>/dev/null | head -1
}

# ---- git --------------------------------------------------------------------

_vault_commit() { # <msg> [--bg]
  local msg="$1" bg="${2:-}"
  [ -d "$MARLOWE_HOME/.git" ] || return 0
  git -C "$MARLOWE_HOME" add -- vault .gitignore 2>/dev/null || true
  if ! git -C "$MARLOWE_HOME" diff --cached --quiet -- vault .gitignore 2>/dev/null; then
    git -C "$MARLOWE_HOME" -c commit.gpgsign=false commit -q -m "$msg" -- vault .gitignore >/dev/null 2>&1 || true
  fi
  git -C "$MARLOWE_HOME" remote get-url origin >/dev/null 2>&1 || return 0
  local branch; branch="$(git -C "$MARLOWE_HOME" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ "$bg" = --bg ]; then
    ( git -C "$MARLOWE_HOME" push -q origin "$branch" >/dev/null 2>&1 && date +%s > "$VAULT_PUSHED" ) &
    disown 2>/dev/null || true
  elif git -C "$MARLOWE_HOME" push -q origin "$branch" 2>/dev/null; then
    date +%s > "$VAULT_PUSHED"
  else
    say "push failed (offline?) — sealed locally, will go up on next save"
  fi
}

# ---- commands ---------------------------------------------------------------

_vault_template() {
  cat <<'EOF'
# Private state

<!-- Loaded by /private. Keep it under ~100 lines: conclusions about your own life,
     not other people's confidences (those stay in the local archive). -->

## Now

## Open threads / next steps

## Log
<!-- one dated line per session, newest first; condense old ones -->

## Archive index
<!-- which ~/.private bundle holds what, without describing contents -->
EOF
}

vault_init() {
  local key=""
  while [ $# -gt 0 ]; do
    case "$1" in --key) key="${2:-}"; shift 2 ;; *) die "usage: marlowe vault init [--key <fingerprint>]" ;; esac
  done
  [ -d "$MARLOWE_HOME" ] || die "no $MARLOWE_HOME — run 'marlowe init'"
  mkdir -p "$VAULT_DIR"
  _vault_ensure_ignore

  if [ -f "$VAULT_DIR/pubkey.gpg" ]; then
    if _vault_have_secret; then
      ok "vault already initialized (key $(_vault_fpr | tail -c 17))"
    elif [ -f "$VAULT_DIR/seckey.gpg" ]; then
      say "importing vault key on this machine (asks for your passphrase)"
      gpg -q --import "$VAULT_DIR/seckey.gpg" || die "key import failed"
      ok "vault key imported"
    else
      die "vault/pubkey.gpg exists but no secret key here or in vault/seckey.gpg"
    fi
    return 0
  fi

  if [ -z "$key" ]; then
    say "generating vault key — a passphrase dialog will open (use a long one; there is no recovery)"
    gpg -q --quick-generate-key "$VAULT_UID" future-default default never || die "key generation failed"
    key="$(gpg --list-keys --with-colons "$VAULT_UID" | awk -F: '$1=="fpr"{print $10}' | tail -1)"
  fi
  gpg --list-secret-keys "$key" >/dev/null 2>&1 || die "no secret key for $key in this keyring"
  gpg --batch -q --export "$key" > "$VAULT_DIR/pubkey.gpg"
  say "exporting the passphrase-protected secret key for other machines (may ask for the passphrase)"
  gpg -q --export-secret-keys "$key" > "$VAULT_DIR/seckey.gpg.tmp" && [ -s "$VAULT_DIR/seckey.gpg.tmp" ] \
    || { rm -f "$VAULT_DIR/seckey.gpg.tmp" "$VAULT_DIR/pubkey.gpg"; die "secret key export failed"; }
  mv -f "$VAULT_DIR/seckey.gpg.tmp" "$VAULT_DIR/seckey.gpg"
  if [ ! -f "$VAULT_DIR/state.md.gpg" ]; then
    _vault_template | _vault_encrypt - "$VAULT_DIR/state.md.gpg"
  fi
  _vault_commit "vault: init"
  ok "vault initialized (key …$(_vault_fpr | tail -c 17))"
}

vault_open() {
  local sid=""
  while [ $# -gt 0 ]; do
    case "$1" in --session) sid="${2:-}"; shift 2 ;; *) die "usage: marlowe vault open [--session <id>]" ;; esac
  done
  _vault_require_init
  [ -d "$MARLOWE_HOME/.git" ] && { timeout 20 git -C "$MARLOWE_HOME" pull -q --ff-only >/dev/null 2>&1 || true; }
  vault_recover --quiet || true

  [ -n "$sid" ] || sid="$(_vault_current_sid 2>/dev/null || true)"
  if [ -n "$sid" ]; then
    local pid tr
    pid="$(_vault_field "$sid" 2)"; [ -n "$pid" ] && [ "$pid" != - ] || pid="$(_vault_claude_pid || echo -)"
    tr="$(_vault_field "$sid" 4)"; { [ -n "$tr" ] && [ "$tr" != - ]; } || tr="$(_vault_find_transcript "$sid")"
    _vault_marker_put "$sid" "$pid" "${tr:--}"
  else
    say "warning: this session isn't registered as private (start it with /private) — hooks will still capture it"
  fi

  if ! _vault_have_secret; then
    [ -f "$VAULT_DIR/seckey.gpg" ] || die "no vault secret key on this machine"
    say "first use on this machine — importing vault key"
    gpg -q --import "$VAULT_DIR/seckey.gpg" || die "key import failed"
  fi

  local work; work="$(_vault_work)"
  mkdir -p "$work"; chmod 700 "$work"
  if [ ! -f "$work/state.md" ]; then
    if [ -f "$VAULT_DIR/state.md.gpg" ]; then
      gpg -q --yes -o "$work/state.md" -d "$VAULT_DIR/state.md.gpg" 2>/dev/null \
        || { _vault_shred_tree "$work"; die "decrypt failed (wrong passphrase or dialog cancelled)"; }
    else
      _vault_template > "$work/state.md"
    fi
    chmod 600 "$work/state.md"
    _vault_sum "$work/state.md" > "$work/.sum"
  fi
  ok "vault open"
  printf 'state: %s\n' "$work/state.md"
  [ -n "$sid" ] && printf 'session: %s (private — not captured)\n' "$sid"
  return 0
}

_vault_save_state() {
  # Encrypt the working state.md into vault/ if it changed. Echoes 1 if it did.
  local work; work="$(_vault_work)"
  [ -f "$work/state.md" ] || return 0
  local now; now="$(_vault_sum "$work/state.md")"
  if [ "$now" != "$(cat "$work/.sum" 2>/dev/null)" ] || [ ! -f "$VAULT_DIR/state.md.gpg" ]; then
    _vault_encrypt "$work/state.md" "$VAULT_DIR/state.md.gpg" && printf '%s' "$now" > "$work/.sum" && echo 1
  fi
}

_vault_checkpoint_transcript() {
  local sid="$1" tr live
  tr="$(_vault_field "$sid" 4)"
  { [ -n "$tr" ] && [ "$tr" != - ] && [ -f "$tr" ]; } || tr="$(_vault_find_transcript "$sid")"
  [ -n "$tr" ] && [ -f "$tr" ] || return 0
  [ "$(_vault_field "$sid" 4)" = "$tr" ] || _vault_marker_put "$sid" "$(_vault_field "$sid" 2)" "$tr"
  live="$VAULT_PRIVATE/live/$sid.jsonl.gpg"
  [ -f "$live" ] && [ ! "$tr" -nt "$live" ] && return 0
  mkdir -p "$VAULT_PRIVATE/live"; chmod 700 "$VAULT_PRIVATE" "$VAULT_PRIVATE/live" 2>/dev/null || true
  _vault_encrypt "$tr" "$live"
}

vault_checkpoint() {
  local quiet=0 sid="" push=1
  while [ $# -gt 0 ]; do
    case "$1" in --quiet) quiet=1; shift ;; --no-push) push=0; shift ;; --session) sid="${2:-}"; shift 2 ;; *) shift ;; esac
  done
  [ -f "$VAULT_DIR/pubkey.gpg" ] || return 0
  local changed; changed="$(_vault_save_state)"
  local s
  if [ -n "$sid" ]; then _vault_checkpoint_transcript "$sid"
  else for s in $(_vault_sessions | cut -f1); do _vault_checkpoint_transcript "$s"; done
  fi
  # Push the encrypted state at most every VAULT_PUSH_EVERY seconds.
  if [ $push -eq 1 ] && { ! git -C "$MARLOWE_HOME" diff --quiet HEAD -- vault 2>/dev/null \
     || [ -n "$(git -C "$MARLOWE_HOME" status --porcelain -- vault 2>/dev/null)" ]; }; then
    local last; last="$(cat "$VAULT_PUSHED" 2>/dev/null || echo 0)"
    if [ $(( $(date +%s) - last )) -ge "$VAULT_PUSH_EVERY" ]; then
      date +%s > "$VAULT_PUSHED"
      _vault_commit "vault: checkpoint" --bg
    fi
  fi
  [ $quiet -eq 1 ] || ok "checkpoint${changed:+ (state updated)}"
}

vault_seal() {
  _vault_require_init
  local work; work="$(_vault_work)"
  vault_checkpoint --quiet --no-push
  _vault_commit "vault: seal"
  _vault_shred_tree "$work"
  ok "vault sealed"
  if _vault_caller_private; then
    say "this session stays marked private until it ends; it's swept automatically then"
  fi
}

_vault_history_split() { # <sid> <keep|take>
  local h="$VAULT_CLAUDE/history.jsonl"
  [ -f "$h" ] || return 0
  if [ "$2" = take ]; then
    jq -R -r --arg s "$1" '. as $l | (try fromjson catch null) as $j
      | if ($j|type)=="object" and $j.sessionId==$s then $l else empty end' "$h"
  else
    jq -R -r --arg s "$1" '. as $l | (try fromjson catch null) as $j
      | if ($j|type)=="object" and $j.sessionId==$s then empty else $l end' "$h"
  fi
}

vault_sweep() {
  local force=0 sids=() quiet=0
  while [ $# -gt 0 ]; do
    case "$1" in --force) force=1; shift ;; --quiet) quiet=1; shift ;; *) sids+=("$1"); shift ;; esac
  done
  [ ${#sids[@]} -gt 0 ] || die "usage: marlowe vault sweep <session-id>… [--force]"
  _vault_require_init
  local sid
  for sid in "${sids[@]}"; do
    case "$sid" in *[!A-Za-z0-9_-]*|"") say "skipping invalid session id"; continue ;; esac
    local pid; pid="$(_vault_field "$sid" 2)"
    if [ $force -eq 0 ] && _vault_alive "$pid" "$(_vault_field "$sid" 3)"; then
      say "session $sid is still running — it's swept when it ends (or use --force)"; continue
    fi
    local stage; stage="$(_vault_ram_base)/marlowe-sweep-$sid"
    _vault_shred_tree "$stage"; mkdir -p "$stage/claude"; chmod 700 "$stage"
    local items=() f
    while IFS= read -r f; do [ -n "$f" ] && items+=("$f"); done < <(
      set +e
      find "$VAULT_CLAUDE/projects" -maxdepth 2 \( -name "$sid.jsonl" -o -name "$sid" \) 2>/dev/null
      for f in "$VAULT_CLAUDE/session-env/$sid" "$VAULT_CLAUDE/file-history/$sid"; do [ -e "$f" ] && echo "$f"; done
      find "$VAULT_CLAUDE/todos" "$VAULT_CLAUDE/debug" -maxdepth 1 -name "*$sid*" 2>/dev/null
      _vault_history_split "$sid" take | jq -r '.pastedContents // {} | .[] | .contentHash // empty' 2>/dev/null \
        | while read -r hsh; do [ -f "$VAULT_CLAUDE/paste-cache/$hsh.txt" ] && echo "$VAULT_CLAUDE/paste-cache/$hsh.txt"; done
      true
    )
    local hist_lines; hist_lines="$(_vault_history_split "$sid" take | wc -l | tr -d ' ')"
    local live="$VAULT_PRIVATE/live/$sid.jsonl.gpg"
    if [ ${#items[@]} -eq 0 ] && [ "$hist_lines" = 0 ]; then
      _vault_shred_tree "$stage"; _vault_marker_del "$sid"
      [ $quiet -eq 1 ] || say "nothing on disk for $sid (live checkpoint kept if any)"
      continue
    fi
    for f in "${items[@]}"; do
      (cd "$VAULT_CLAUDE" && cp -a --parents "${f#"$VAULT_CLAUDE"/}" "$stage/claude/")
    done
    _vault_history_split "$sid" take > "$stage/claude/history.session.jsonl"
    { printf 'session %s\nswept %s\nhost %s\n' "$sid" "$(date -Iseconds)" "$(hostname)"
      printf '%s\n' "${items[@]}"; } > "$stage/MANIFEST"
    local out="$VAULT_PRIVATE/sessions/$(date +%F)-$sid.tar.gpg"
    mkdir -p "$VAULT_PRIVATE/sessions"; chmod 700 "$VAULT_PRIVATE" "$VAULT_PRIVATE/sessions" 2>/dev/null || true
    if ! (cd "$stage" && tar -cf - .) | _vault_encrypt - "$out" || [ ! -s "$out" ]; then
      _vault_shred_tree "$stage"; say "archive of $sid failed — nothing deleted"; continue
    fi
    # Archive is safe; now remove the originals.
    _vault_shred_tree "${items[@]}"
    if [ "$hist_lines" != 0 ]; then
      local h="$VAULT_CLAUDE/history.jsonl"
      _vault_history_split "$sid" keep > "$h.vault-tmp" && chmod --reference="$h" "$h.vault-tmp" 2>/dev/null
      mv -f "$h.vault-tmp" "$h"
    fi
    rm -f "$live"
    _vault_shred_tree "$stage"
    _vault_marker_del "$sid"
    [ $quiet -eq 1 ] || ok "swept $sid → ${out/#$HOME/\~} (${#items[@]} paths, $hist_lines history lines)"
  done
}

vault_recover() {
  local quiet=0; [ "${1:-}" = --quiet ] && quiet=1
  [ -f "$VAULT_DIR/pubkey.gpg" ] || return 0
  local n=0 sid pid
  local started
  while IFS=$'\t' read -r sid pid started _; do
    [ -n "$sid" ] || continue
    _vault_alive "$pid" "$started" && continue
    vault_checkpoint --quiet --no-push --session "$sid"
    vault_sweep --force --quiet "$sid"
    n=$((n + 1))
  done < <(_vault_sessions)
  local work; work="$(_vault_work)"
  if [ ! -s "$VAULT_MARKER" ] && [ -d "$work" ] && [ $n -gt 0 ]; then
    _vault_save_state >/dev/null
    _vault_commit "vault: seal" --bg
    _vault_shred_tree "$work"
  fi
  if [ $n -gt 0 ] && [ $quiet -eq 0 ]; then
    say "cleaned up $n private session(s) that ended without /private end"
  fi
  [ $n -gt 0 ] && printf '%s' "$n" > "$MARLOWE_HOME/.vault-recovered" 2>/dev/null
  return 0
}

vault_status() {
  if [ ! -f "$VAULT_DIR/pubkey.gpg" ]; then say "vault: not initialized ('marlowe vault init')"; return 0; fi
  local work; work="$(_vault_work)"
  say "vault: key …$(_vault_fpr | tail -c 17)$(_vault_have_secret || printf ' (secret key not on this machine)')"
  if [ -f "$work/state.md" ]; then ok "open: $work/state.md"; else ok "closed"; fi
  local sid pid started
  while IFS=$'\t' read -r sid pid started _; do
    [ -n "$sid" ] || continue
    if _vault_alive "$pid" "$started"; then ok "private session $sid (running since $started)"
    else printf '  %s!%s orphaned session %s — run: marlowe vault recover\n' "$PINK" "$RESET" "$sid"; fi
  done < <(_vault_sessions)
  local last; last="$(git -C "$MARLOWE_HOME" log -1 --format='%cr' -- vault/state.md.gpg 2>/dev/null || true)"
  [ -n "$last" ] && ok "state last committed $last"
  local nl ns
  nl="$(find "$VAULT_PRIVATE/live" -name '*.gpg' 2>/dev/null | wc -l | tr -d ' ')"
  ns="$(find "$VAULT_PRIVATE/sessions" -name '*.gpg' 2>/dev/null | wc -l | tr -d ' ')"
  ok "archive: $ns swept session(s), $nl live checkpoint(s) in ${VAULT_PRIVATE/#$HOME/\~}"
  local stray; stray="$(find "$VAULT_DIR" -type f ! -name '*.gpg' 2>/dev/null)"
  [ -z "$stray" ] || printf '  %s!%s plaintext under vault/: %s\n' "$PINK" "$RESET" "$stray"
}

vault_archive() {
  local src="" name="" do_shred=0
  while [ $# -gt 0 ]; do
    case "$1" in --name) name="${2:-}"; shift 2 ;; --shred) do_shred=1; shift ;; *) src="$1"; shift ;; esac
  done
  [ -d "$src" ] || die "usage: marlowe vault archive <dir> [--name <label>] [--shred]"
  _vault_require_init
  local out="$VAULT_PRIVATE/$(date +%F)-${name:-personal}.tar.gpg" i=2
  while [ -e "$out" ]; do out="$VAULT_PRIVATE/$(date +%F)-${name:-personal}-$i.tar.gpg"; i=$((i + 1)); done
  mkdir -p "$VAULT_PRIVATE"; chmod 700 "$VAULT_PRIVATE"
  (cd "$src" && tar -cf - .) | _vault_encrypt - "$out" && [ -s "$out" ] || die "archive failed"
  ok "archived → ${out/#$HOME/\~}"
  if [ $do_shred -eq 1 ]; then _vault_shred_tree "$src"; ok "source shredded"; fi
}

vault_hook() {
  # Claude Code hook entrypoint. Never fails, never blocks the session.
  local event="${1:-}" input sid prompt tr
  input="$(cat 2>/dev/null || true)"
  sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
  case "$sid" in *[!A-Za-z0-9_-]*) return 0 ;; esac
  [ -f "$VAULT_DIR/pubkey.gpg" ] || return 0
  case "$event" in
    prompt)
      prompt="$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null || true)"
      if [ -n "$sid" ] && printf '%s' "$prompt" | grep -Eq '^[[:space:]]*/private([[:space:]]|$)'; then
        tr="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
        _vault_marker_put "$sid" "$(_vault_claude_pid || echo -)" "${tr:--}"
      fi ;;
    stop)
      [ -n "$sid" ] && [ -n "$(_vault_field "$sid" 1)" ] && vault_checkpoint --quiet --session "$sid" ;;
    start)
      vault_recover --quiet >/dev/null 2>&1 || true
      if [ -f "$MARLOWE_HOME/.vault-recovered" ]; then
        echo "marlowe: $(cat "$MARLOWE_HOME/.vault-recovered") private session(s) had ended without /private end — they were checkpointed, archived to ~/.private and swept. Tell the user in one line."
        rm -f "$MARLOWE_HOME/.vault-recovered"
      fi ;;
    end)
      # Checkpoint now; mark the session ended and sweep a few seconds later in a
      # detached process, after Claude Code has written its last transcript lines.
      # If that process never runs, the next SessionStart's recover picks it up.
      if [ -n "$sid" ] && [ -n "$(_vault_field "$sid" 1)" ]; then
        vault_checkpoint --quiet --session "$sid"
        _vault_marker_put "$sid" ended -
        local self; self="$MARLOWE_FRAMEWORK/bin/marlowe"
        if command -v setsid >/dev/null 2>&1; then
          setsid nohup bash -c "sleep ${MARLOWE_VAULT_END_DELAY:-4}; '$self' vault recover --quiet" >/dev/null 2>&1 < /dev/null &
        else
          nohup bash -c "sleep ${MARLOWE_VAULT_END_DELAY:-4}; '$self' vault recover --quiet" >/dev/null 2>&1 < /dev/null &
        fi
      fi ;;
  esac
  return 0
}

cmd_vault() {
  local sub="${1:-status}"; shift || true
  case "$sub" in
    init)       vault_init "$@" ;;
    open)       vault_open "$@" ;;
    seal|close) vault_seal "$@" ;;
    checkpoint) vault_checkpoint "$@" ;;
    sweep)      vault_sweep "$@" ;;
    recover)    vault_recover "$@" ;;
    status)     vault_status "$@" ;;
    archive)    vault_archive "$@" ;;
    hook)       { vault_hook "$@"; } 2>/dev/null || true ;;
    *) die "usage: marlowe vault <init|open|seal|checkpoint|sweep|recover|status|archive|hook>" ;;
  esac
}
