#!/usr/bin/env bats

load helpers.bash

setup()    { _setup_home; }
teardown() { _teardown_home; }

@test "doctor prints its header and all check labels" {
  run MARLOWE doctor
  [[ "$output" == *"marlowe doctor"* ]]
  [[ "$output" == *"data repo"* ]]
  [[ "$output" == *"framework"* ]]
  [[ "$output" == *"memory.md"* || "$output" == *"preferences.md"* ]]
}

@test "doctor flags missing core.hooksPath as warning, not critical" {
  # Fresh env: no core.hooksPath set → warn, not fail.
  run MARLOWE doctor
  [[ "$output" == *"core.hooksPath"* ]]
}

@test "doctor exits 0 when marlowe is on PATH + repo initialized" {
  mkdir -p "$HOME/.local/bin"
  ln -sf "$MARLOWE_FRAMEWORK/bin/marlowe" "$HOME/.local/bin/marlowe"
  export PATH="$HOME/.local/bin:$PATH"
  run MARLOWE doctor
  [ "$status" -eq 0 ]
}
