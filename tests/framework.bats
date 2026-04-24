#!/usr/bin/env bats

load helpers.bash

setup()    { _setup_home; }
teardown() { _teardown_home; }

@test "marlowe self-locates MARLOWE_FRAMEWORK when unset" {
  # Unset and invoke directly — bin/marlowe should derive its own framework
  # from $BASH_SOURCE and still operate correctly.
  unset MARLOWE_FRAMEWORK
  mkdir -p "$HOME/.claude"
  run "$BATS_TEST_DIRNAME/../bin/marlowe" apply claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"applied"* ]]
  grep -q '<!-- marlowe:begin -->' "$HOME/.claude/CLAUDE.md"
}

@test "MARLOWE_FRAMEWORK is exported to adapter scripts" {
  # Regression for the v0.10.1 bug: plain assignment doesn't propagate to
  # child processes. Apply loop sources render.sh from $MARLOWE_FRAMEWORK;
  # if it's not exported, adapter fails with "No such file or directory".
  unset MARLOWE_FRAMEWORK
  mkdir -p "$HOME/.claude"
  # Invoke save — this triggers the adapter re-apply loop internally.
  run "$BATS_TEST_DIRNAME/../bin/marlowe" save
  [ "$status" -eq 0 ]
  # Error messages would appear in output if adapter couldn't find render.sh
  [[ "$output" != *"No such file or directory"* ]]
  [[ "$output" != *"render.sh"* ]]
}
