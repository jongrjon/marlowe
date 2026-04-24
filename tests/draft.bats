#!/usr/bin/env bats

load helpers.bash

setup()    { _setup_home; }
teardown() { _teardown_home; }

@test "draft appends a line to drafts.md" {
  MARLOWE draft "candidate fact from AI"
  [ -f "$MARLOWE_HOME/drafts.md" ]
  grep -q "candidate fact from AI" "$MARLOWE_HOME/drafts.md"
}

@test "draft bumps the 'draft' counter" {
  MARLOWE draft "one"
  MARLOWE draft "two"
  [ -f "$MARLOWE_HOME/.counters" ]
  run grep -E '^draft ' "$MARLOWE_HOME/.counters"
  [[ "$output" == "draft 2" ]]
}

@test "draft is gitignored after wire" {
  MARLOWE wire "$HOME/.bashrc"
  grep -q '^drafts\.md$' "$MARLOWE_HOME/.gitignore"
}

@test "draft without args errors out" {
  run MARLOWE draft
  [ "$status" -ne 0 ]
}
