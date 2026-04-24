#!/usr/bin/env bats

load helpers.bash

setup()    { _setup_home; }
teardown() { _teardown_home; }

# Seed a projects.md directly so we don't depend on interactive ask() prompts.
_seed_projects() {
  cat > "$MARLOWE_HOME/projects.md" <<EOF
# Projects

<!-- managed via \`marlowe project add|list\`. Format: -->
<!-- - name | path | git | brief (≤80 chars) -->

$1
EOF
}

@test "project list shows seeded entries" {
  _seed_projects "- foo | /tmp/foo | gh:x/foo | a brief"
  run MARLOWE project list
  [ "$status" -eq 0 ]
  [[ "$output" == *"foo"* ]]
  [[ "$output" == *"a brief"* ]]
}

@test "project remove deletes the named entry" {
  _seed_projects "- foo | /tmp/foo | gh:x/foo | a
- bar | /tmp/bar | gh:x/bar | b"
  MARLOWE project remove foo
  run grep -c '^- ' "$MARLOWE_HOME/projects.md"
  [ "$output" = "1" ]
  grep -q "bar" "$MARLOWE_HOME/projects.md"
  ! grep -q "^- foo" "$MARLOWE_HOME/projects.md"
}

@test "project remove on missing name errors out" {
  _seed_projects "- foo | /tmp/foo | gh:x/foo | a"
  run MARLOWE project remove nosuch
  [ "$status" -ne 0 ]
}

@test "project brief updates only the brief field" {
  _seed_projects "- foo | /tmp/foo | gh:x/foo | old brief"
  MARLOWE project brief foo "the new brief"
  grep -q "the new brief" "$MARLOWE_HOME/projects.md"
  ! grep -q "old brief" "$MARLOWE_HOME/projects.md"
  # path and git preserved
  grep -q "/tmp/foo" "$MARLOWE_HOME/projects.md"
  grep -q "gh:x/foo" "$MARLOWE_HOME/projects.md"
}

@test "project activate sets override and --clear drops it" {
  _seed_projects "- foo | /tmp/foo | gh:x/foo | a"
  MARLOWE project activate foo
  [ -f "$MARLOWE_HOME/.active-project" ]
  run MARLOWE project active
  [[ "$output" == "foo" ]]
  MARLOWE project activate --clear
  [ ! -f "$MARLOWE_HOME/.active-project" ]
}

@test "project active uses longest-path match" {
  mkdir -p /tmp/pa-$$/inner
  _seed_projects "- outer | /tmp/pa-$$ | gh:x/a | outer
- inner | /tmp/pa-$$/inner | gh:x/b | inner"
  cd /tmp/pa-$$/inner
  run MARLOWE project active
  [[ "$output" == "inner" ]]
  rm -rf /tmp/pa-$$
}

@test "project active returns error when no match" {
  _seed_projects "- foo | /tmp/foo | gh:x/foo | a"
  cd /tmp
  run MARLOWE project active
  [ "$status" -ne 0 ]
}
