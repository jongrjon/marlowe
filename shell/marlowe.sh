# marlowe — shell integration (bash/zsh). Logs an activity the first time you
# enter a new git repo in a shell session. Zero LLM cost; runs async so the
# prompt never waits.

__marlowe_last_repo=""

__marlowe_prompt_hook() {
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -n "$top" ] || return 0
  [ "$top" = "$__marlowe_last_repo" ] && return 0
  __marlowe_last_repo="$top"
  ( marlowe activity "enter ${top##*/} ($top)" >/dev/null 2>&1 & )
}

# bash: splice into PROMPT_COMMAND if not already there
if [ -n "${BASH_VERSION:-}" ]; then
  case ":${PROMPT_COMMAND:-}:" in
    *__marlowe_prompt_hook*) ;;
    *) PROMPT_COMMAND="__marlowe_prompt_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
  esac
fi

# zsh: use precmd hook
if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz add-zsh-hook 2>/dev/null
  add-zsh-hook precmd __marlowe_prompt_hook 2>/dev/null
fi
