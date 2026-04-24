#!/usr/bin/env bats

load helpers.bash

setup()    { _setup_home; }
teardown() { _teardown_home; }

@test "review falls back to light mode when memory <= 4K" {
  MARLOWE draft "small candidate"
  run MARLOWE review --yes
  [ "$status" -eq 0 ]
  grep -q "small candidate" "$MARLOWE_HOME/memory.md"
}

@test "review --audit with no claude on PATH falls back to light" {
  # Narrow PATH so `command -v claude` fails inside marlowe
  local saved="$PATH"
  export PATH="/usr/bin:/bin"
  run MARLOWE review --audit --yes
  export PATH="$saved"
  [ "$status" -eq 0 ]
  [[ "$output" == *"falling back"* || "$output" == *"light"* ]]
}

@test "review --no-audit on >4K memory stays in light mode" {
  {
    echo "# Memory"
    local i=0
    while [ $i -lt 80 ]; do
      printf -- '- [2026-04-24] synthetic entry %d padded with extra text to fill bytes\n' "$i"
      i=$((i + 1))
    done
  } > "$MARLOWE_HOME/memory.md"
  local before
  before="$(wc -c < "$MARLOWE_HOME/memory.md")"
  [ "$before" -gt 4096 ]
  MARLOWE draft "new note under no-audit"
  run MARLOWE review --no-audit --yes
  [ "$status" -eq 0 ]
  # Light mode preserves existing entries and appends new ones
  grep -q "synthetic entry 0" "$MARLOWE_HOME/memory.md"
  grep -q "new note under no-audit" "$MARLOWE_HOME/memory.md"
}

@test "review on >4K memory with no claude falls back to light" {
  {
    echo "# Memory"
    local i=0
    while [ $i -lt 80 ]; do
      printf -- '- [2026-04-24] synthetic entry %d padded with extra text to fill bytes\n' "$i"
      i=$((i + 1))
    done
  } > "$MARLOWE_HOME/memory.md"
  MARLOWE draft "fallback test"
  local saved="$PATH"
  export PATH="/usr/bin:/bin"
  run MARLOWE review --yes
  export PATH="$saved"
  [ "$status" -eq 0 ]
  grep -q "fallback test" "$MARLOWE_HOME/memory.md"
  grep -q "synthetic entry 0" "$MARLOWE_HOME/memory.md"
}
