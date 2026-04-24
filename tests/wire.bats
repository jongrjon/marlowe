#!/usr/bin/env bats

load helpers.bash

setup()    { _setup_home; }
teardown() { _teardown_home; }

@test "wire appends shell hook line to bashrc" {
  MARLOWE wire "$HOME/.bashrc"
  grep -q "shell/marlowe.sh" "$HOME/.bashrc"
}

@test "wire is idempotent on the shell rc" {
  MARLOWE wire "$HOME/.bashrc"
  local before
  before="$(md5sum "$HOME/.bashrc" | cut -d' ' -f1)"
  MARLOWE wire "$HOME/.bashrc"
  local after
  after="$(md5sum "$HOME/.bashrc" | cut -d' ' -f1)"
  [ "$before" = "$after" ]
}

@test "wire adds activities.md* and .counters and .active-project to gitignore" {
  MARLOWE wire "$HOME/.bashrc"
  grep -q '^activities\.md\*$' "$MARLOWE_HOME/.gitignore"
  grep -q '^\.counters$' "$MARLOWE_HOME/.gitignore"
  grep -q '^\.active-project$' "$MARLOWE_HOME/.gitignore"
}

@test "wire sets global core.hooksPath when unset" {
  MARLOWE wire "$HOME/.bashrc"
  run git config --global --get core.hooksPath
  [[ "$output" == *"$MARLOWE_FRAMEWORK/hooks"* ]]
}
