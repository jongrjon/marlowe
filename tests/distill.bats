#!/usr/bin/env bats

load helpers.bash

setup()    { _setup_home; }
teardown() { _teardown_home; }

@test "distill without activities.md says 'nothing to distill'" {
  run MARLOWE distill
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to distill"* ]]
}

@test "distill on empty activities.md is a no-op" {
  : > "$MARLOWE_HOME/activities.md"
  run MARLOWE distill
  [ "$status" -eq 0 ]
  [[ "$output" == *"empty"* ]] || [[ "$output" == *"nothing"* ]]
}

@test "distill --if-over skips below threshold" {
  printf '[2026-04-24T00:00:00+00:00] [host] one\n' >  "$MARLOWE_HOME/activities.md"
  printf '[2026-04-24T00:00:01+00:00] [host] two\n' >> "$MARLOWE_HOME/activities.md"
  run MARLOWE distill --if-over 99
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
  # File untouched
  [ "$(wc -l < "$MARLOWE_HOME/activities.md")" = "2" ]
}
