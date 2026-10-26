#!/usr/bin/env bash

# Shared terminal presentation for ravn-git-bare-clone.
if [[ ${_PRESENTATION_SOURCED:-0} -eq 1 ]]; then
  # shellcheck disable=SC2317
  return 0 2> /dev/null || exit 0
fi
readonly _PRESENTATION_SOURCED=1

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$lib_dir/global_fn.sh"
