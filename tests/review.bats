#!/usr/bin/env bats

load helpers.bash

setup()    { _setup_home; }
teardown() { _teardown_home; }

@test "review with empty drafts and no activities is a no-op" {
  run MARLOWE review --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to review"* ]]
}

@test "review --yes promotes all drafts to memory.md" {
  MARLOWE draft "first candidate"
  MARLOWE draft "second candidate"
  run MARLOWE review --yes
  [ "$status" -eq 0 ]
  grep -q "first candidate" "$MARLOWE_HOME/memory.md"
  grep -q "second candidate" "$MARLOWE_HOME/memory.md"
}

@test "review clears drafts.md after run" {
  MARLOWE draft "will be promoted"
  MARLOWE review --yes
  [ -f "$MARLOWE_HOME/drafts.md" ]
  run grep -cE '^- ' "$MARLOWE_HOME/drafts.md"
  [[ "$output" == "0" ]]
}

@test "review promotion gets a dated header" {
  MARLOWE draft "tagged candidate"
  MARLOWE review --yes
  grep -qE '^## Reviewed [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$MARLOWE_HOME/memory.md"
}
