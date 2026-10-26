#!/usr/bin/env bash

# shellcheck disable=SC1091 # Sourced from library dir.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/command_catalog.sh"

# Run a command module's operation or its self-describing help.
run_command_entrypoint() {
  local command_name="$1"
  local help_function="$2"
  local operation_function="$3"
  local options=""
  shift 3

  command_catalog_get "$command_name" options || return 1
  options="$RAVN_GIT_BARE_CLONE_COMMAND_CATALOG_VALUE"

  if (($# == 0)); then
    "$operation_function"
    return $?
  fi

  if (($# == 1)) && [[ " $options " == *" $1 "* ]]; then
    "$help_function"
    return 0
  fi

  print_error "Unknown option for $command_name: $1"
  "$help_function"
  return 2
}
