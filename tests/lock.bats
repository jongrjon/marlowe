#!/usr/bin/env bats

load helpers.bash

setup()    { _setup_home; }
teardown() { _teardown_home; }

@test "lockfile is created on first write-side command" {
  MARLOWE save >/dev/null 2>&1 || true
  [ -f "$MARLOWE_HOME/.git/marlowe.lock" ]
}

@test "lockfile lives inside .git so it's never tracked" {
  MARLOWE save >/dev/null 2>&1 || true
  cd "$MARLOWE_HOME"
  run git status --porcelain
  # .git/marlowe.lock must not appear in status output
  [[ "$output" != *"marlowe.lock"* ]]
}
