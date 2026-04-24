#!/usr/bin/env bats

load helpers.bash

setup()    { _setup_home; }
teardown() { _teardown_home; }

@test "activity appends a line to activities.md" {
  MARLOWE activity "hello from bats"
  [ -f "$MARLOWE_HOME/activities.md" ]
  grep -q "hello from bats" "$MARLOWE_HOME/activities.md"
}

@test "activity bumps the 'activity' counter" {
  MARLOWE activity "one"
  MARLOWE activity "two"
  MARLOWE activity "three"
  [ -f "$MARLOWE_HOME/.counters" ]
  run grep -E '^activity ' "$MARLOWE_HOME/.counters"
  [ "$status" -eq 0 ]
  [[ "$output" == "activity 3" ]]
}

@test "activity with empty msg is a no-op" {
  MARLOWE activity ""
  # activities.md should not exist, or at worst be empty
  if [ -f "$MARLOWE_HOME/activities.md" ]; then
    [ ! -s "$MARLOWE_HOME/activities.md" ]
  fi
}
