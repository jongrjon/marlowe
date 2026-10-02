#!/usr/bin/env bats

load helpers.bash

# Each test gets its own GNUPGHOME with an unprotected throwaway key, a fake
# ~/.claude tree, and a RAM-dir stand-in, so nothing touches real keys or data.
setup() {
  _setup_home
  export GNUPGHOME="$HOME/.gnupg"
  mkdir -m 700 -p "$GNUPGHOME"
  gpg --batch -q --passphrase '' --quick-generate-key "Test Vault <t@test.local>" future-default default never 2>/dev/null
  FPR="$(gpg --list-keys --with-colons | awk -F: '$1=="fpr"{print $10; exit}')"
  export MARLOWE_VAULT_WORK="$HOME/ram/work"
  export MARLOWE_PRIVATE="$HOME/private"
  export MARLOWE_VAULT_PROC_RE='^sleep$'
  export MARLOWE_VAULT_END_DELAY=0
  mkdir -p "$HOME/ram" "$HOME/.claude/projects/-proj" "$HOME/.claude/paste-cache" "$HOME/.claude/session-env"
  unset CLAUDE_SESSION_ID
}
teardown() {
  gpgconf --kill gpg-agent 2>/dev/null || true
  for p in "${SLEEPERS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done
  _teardown_home
}

_init()     { MARLOWE vault init --key "$FPR" >/dev/null; }
_session()  { # _session <sid> — fake transcript + history + paste
  echo '{"type":"user","text":"secret-words"}' > "$HOME/.claude/projects/-proj/$1.jsonl"
  mkdir -p "$HOME/.claude/projects/-proj/$1/subagents" "$HOME/.claude/session-env/$1"
  echo x > "$HOME/.claude/projects/-proj/$1/subagents/a.jsonl"
  echo "pasted-secret" > "$HOME/.claude/paste-cache/h$1.txt"
  printf '{"display":"secret prompt","sessionId":"%s","pastedContents":{"1":{"id":1,"type":"text","contentHash":"h%s"}}}\n' "$1" "$1" >> "$HOME/.claude/history.jsonl"
  printf '{"display":"keep me","sessionId":"other"}\n' >> "$HOME/.claude/history.jsonl"
}
_hook()     { printf '%s' "$2" | MARLOWE vault hook "$1"; }
_sleeper()  { sleep 300 >/dev/null 2>&1 & pid=$!; SLEEPERS+=("$pid"); }

@test "init exports keys, seeds encrypted state, commits only ciphertext" {
  _init
  [ -s "$MARLOWE_HOME/vault/pubkey.gpg" ]
  [ -s "$MARLOWE_HOME/vault/seckey.gpg" ]
  [ -s "$MARLOWE_HOME/vault/state.md.gpg" ]
  run git -C "$MARLOWE_HOME" ls-files vault
  [[ "$output" == *pubkey.gpg* && "$output" == *state.md.gpg* ]]
  grep -qx '.vault-open' "$MARLOWE_HOME/.gitignore"
  grep -qx '!vault/\*.gpg' "$MARLOWE_HOME/.gitignore"
}

@test "open decrypts into the RAM dir, seal re-encrypts and shreds it" {
  _init
  run MARLOWE vault open
  [ "$status" -eq 0 ]
  [[ "$output" == *"state: $MARLOWE_VAULT_WORK/state.md"* ]]
  grep -q '## Open threads' "$MARLOWE_VAULT_WORK/state.md"
  echo "- new fact zebra" >> "$MARLOWE_VAULT_WORK/state.md"
  MARLOWE vault seal
  [ ! -e "$MARLOWE_VAULT_WORK" ]
  gpg -q -d "$MARLOWE_HOME/vault/state.md.gpg" 2>/dev/null | grep -q zebra
  run git -C "$MARLOWE_HOME" log --format=%s
  [[ "$output" == *"vault: seal"* ]]
  [[ "$output" != *zebra* ]]
  run git -C "$MARLOWE_HOME" log -p
  [[ "$output" != *zebra* ]]
}

@test "save refuses when plaintext sits under vault/" {
  _init
  echo leak > "$MARLOWE_HOME/vault/state.md"
  run MARLOWE save -m test
  [ "$status" -ne 0 ]
  [[ "$output" == *"plaintext under vault/"* ]]
}

@test "prompt hook registers /private sessions only" {
  _init
  _hook prompt '{"session_id":"s-normal","prompt":"fix nginx"}'
  [ ! -s "$MARLOWE_HOME/.vault-open" ]
  _hook prompt '{"session_id":"s-priv","prompt":"/private","transcript_path":"/x/s-priv.jsonl"}'
  grep -q '^s-priv	' "$MARLOWE_HOME/.vault-open"
  git -C "$MARLOWE_HOME" check-ignore -q .vault-open
}

@test "stop hook checkpoints state and transcript, encrypted" {
  _init
  _session s1
  _hook prompt "{\"session_id\":\"s1\",\"prompt\":\"/private\",\"transcript_path\":\"$HOME/.claude/projects/-proj/s1.jsonl\"}"
  MARLOWE vault open --session s1 >/dev/null
  echo "- checkpointed fact" >> "$MARLOWE_VAULT_WORK/state.md"
  _hook stop '{"session_id":"s1"}'
  [ -s "$MARLOWE_PRIVATE/live/s1.jsonl.gpg" ]
  ! grep -q secret-words "$MARLOWE_PRIVATE/live/s1.jsonl.gpg"
  gpg -q -d "$MARLOWE_PRIVATE/live/s1.jsonl.gpg" 2>/dev/null | grep -q secret-words
  gpg -q -d "$MARLOWE_HOME/vault/state.md.gpg" 2>/dev/null | grep -q 'checkpointed fact'
}

@test "sweep archives a session's files and removes only that session" {
  _init
  _session s2
  MARLOWE vault sweep s2
  [ ! -e "$HOME/.claude/projects/-proj/s2.jsonl" ]
  [ ! -e "$HOME/.claude/projects/-proj/s2" ]
  [ ! -e "$HOME/.claude/session-env/s2" ]
  [ ! -e "$HOME/.claude/paste-cache/hs2.txt" ]
  ! grep -q '"s2"' "$HOME/.claude/history.jsonl"
  grep -q 'keep me' "$HOME/.claude/history.jsonl"
  arc="$(ls "$MARLOWE_PRIVATE"/sessions/*-s2.tar.gpg)"
  run bash -c "gpg -q -d '$arc' 2>/dev/null | tar -tf -"
  [[ "$output" == *"projects/-proj/s2.jsonl"* ]]
  [[ "$output" == *"paste-cache/hs2.txt"* ]]
  [[ "$output" == *"history.session.jsonl"* ]]
}

@test "sweep leaves a running private session alone unless forced" {
  _init
  _session s3
  _sleeper
  printf 's3\t%s\tnow\t-\n' "$pid" > "$MARLOWE_HOME/.vault-open"
  run MARLOWE vault sweep s3
  [[ "$output" == *"still running"* ]]
  [ -e "$HOME/.claude/projects/-proj/s3.jsonl" ]
}

@test "crash: kill -9 the session process, next start hook recovers it" {
  _init
  _session s4
  _sleeper
  _hook prompt "{\"session_id\":\"s4\",\"prompt\":\"/private hi\",\"transcript_path\":\"$HOME/.claude/projects/-proj/s4.jsonl\"}"
  # the hook can't see a claude ancestor in tests; pin the pid by hand
  printf 's4\t%s\tnow\t%s\n' "$pid" "$HOME/.claude/projects/-proj/s4.jsonl" > "$MARLOWE_HOME/.vault-open"
  MARLOWE vault open --session s4 >/dev/null
  echo "- unsaved before crash" >> "$MARLOWE_VAULT_WORK/state.md"
  kill -9 "$pid"; wait "$pid" 2>/dev/null || true
  run _hook start '{"session_id":"new"}'
  [[ "$output" == *"private session(s) had ended"* ]]
  [ ! -e "$HOME/.claude/projects/-proj/s4.jsonl" ]
  [ ! -s "$MARLOWE_HOME/.vault-open" ]
  [ ! -e "$MARLOWE_VAULT_WORK" ]
  ls "$MARLOWE_PRIVATE"/sessions/*-s4.tar.gpg
  gpg -q -d "$MARLOWE_HOME/vault/state.md.gpg" 2>/dev/null | grep -q 'unsaved before crash'
}

@test "end hook checkpoints, then sweeps after the process exits" {
  _init
  _session s5
  printf 's5\tended\tnow\t%s\n' "$HOME/.claude/projects/-proj/s5.jsonl" > "$MARLOWE_HOME/.vault-open"
  _hook end '{"session_id":"s5"}'
  for i in $(seq 1 50); do [ -e "$HOME/.claude/projects/-proj/s5.jsonl" ] || break; sleep 0.1; done
  [ ! -e "$HOME/.claude/projects/-proj/s5.jsonl" ]
  ls "$MARLOWE_PRIVATE"/sessions/*-s5.tar.gpg
}

@test "remember and draft refuse inside a private session" {
  _init
  printf 's6\tended\tnow\t-\n' > "$MARLOWE_HOME/.vault-open"
  CLAUDE_SESSION_ID=s6 run MARLOWE remember "private thing"
  [ "$status" -ne 0 ]
  [[ "$output" == *"private session"* ]]
  CLAUDE_SESSION_ID=s6 run MARLOWE draft "private thing"
  [ "$status" -ne 0 ]
  ! grep -rq "private thing" "$MARLOWE_HOME"
}

@test "new machine: fresh keyring imports the key from vault/ and opens" {
  _init
  MARLOWE vault open >/dev/null; echo "- travels" >> "$MARLOWE_VAULT_WORK/state.md"; MARLOWE vault seal >/dev/null
  gpgconf --kill gpg-agent
  export GNUPGHOME="$HOME/.gnupg2"; mkdir -m 700 -p "$GNUPGHOME"
  run MARLOWE vault open
  [ "$status" -eq 0 ]
  grep -q travels "$MARLOWE_VAULT_WORK/state.md"
}

@test "status reports orphaned sessions" {
  _init
  printf 'dead1\t999999\tnow\t-\n' > "$MARLOWE_HOME/.vault-open"
  run MARLOWE vault status
  [ "$status" -eq 0 ]
  [[ "$output" == *"orphaned session dead1"* ]]
  [[ "$output" == *"archive: 0 swept session(s)"* ]]
}
