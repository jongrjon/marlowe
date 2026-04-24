# Shared bats setup for marlowe tests. Isolates every test to a throwaway
# HOME / MARLOWE_HOME / GIT_CONFIG_GLOBAL so nothing touches the user's real
# dotfiles, repos, or git config.

_setup_home() {
  export MARLOWE_FRAMEWORK
  MARLOWE_FRAMEWORK="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  local tmp
  tmp="$(mktemp -d)"
  export HOME="$tmp"
  export MARLOWE_HOME="$HOME/.marlowe"
  export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  touch "$GIT_CONFIG_GLOBAL"

  mkdir -p "$MARLOWE_HOME"
  cd "$MARLOWE_HOME" || return 1
  git init -q -b main
  git config user.name "Test"
  git config user.email "test@test.local"
  git config commit.gpgsign false

  cp "$MARLOWE_FRAMEWORK/templates/preferences.md" preferences.md
  sed -i 's/__USER_NAME__/Test/; s/__ASSISTANT_NAME__/Assistant/' preferences.md
  echo "generated/" > .gitignore
  git add .
  git commit -q -m "init"

  touch "$HOME/.bashrc"
}

_teardown_home() {
  cd /
  [ -n "${HOME:-}" ] && [ -d "$HOME" ] && [[ "$HOME" == /tmp/* ]] && rm -rf "$HOME"
}

# Invoke marlowe binary under test; callable as `MARLOWE <subcmd>`.
MARLOWE() {
  "$MARLOWE_FRAMEWORK/bin/marlowe" "$@"
}
