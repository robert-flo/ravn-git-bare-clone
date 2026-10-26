#!/usr/bin/env bash

if [[ ${_GIT_BARE_CLONE_BASH_COMPLETION_LOADED:-0} == 1 ]]; then
  return 0
fi
readonly _GIT_BARE_CLONE_BASH_COMPLETION_LOADED=1

GIT_BARE_CLONE_COMPLETION_DIR=""
GIT_BARE_CLONE_COMPLETION_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly GIT_BARE_CLONE_COMPLETION_DIR
# shellcheck disable=SC1091
source "$GIT_BARE_CLONE_COMPLETION_DIR/../lib/command_catalog.sh"

_git_bare_clone_completion() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local previous="${COMP_WORDS[COMP_CWORD - 1]:-}"
  local commands=""
  local options=""

  if ((COMP_CWORD == 1)); then
    commands=$(command_catalog_completion_words)
    if [[ $current == -* ]]; then
      if command_catalog_get "clone" options; then
        commands="$commands $RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_VALUE"
      fi
    fi
    # shellcheck disable=SC2207 # Bash completion requires word splitting here.
    COMPREPLY=($( compgen -W "$commands" -- "$current"))
    return 0
  fi

  if command_catalog_get "$previous" options; then
    options="$RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_VALUE"
    # shellcheck disable=SC2207 # Bash completion requires word splitting here.
    COMPREPLY=($( compgen -W "$options" -- "$current"))
  fi
}

complete -F _git_bare_clone_completion ravn-git-bare-clone git-bare-clone
