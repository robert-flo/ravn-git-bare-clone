#!/usr/bin/env bash

# Shared repository, runtime, and default worktree/bare configuration paths.
helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RUNTIME_DIR="${RUNTIME_DIR:-$(cd "$helper_dir/.." && pwd)}"
readonly RAVN_GIT_BARE_CLONE_ROOT="${RAVN_GIT_BARE_CLONE_ROOT:-$(cd "$RUNTIME_DIR/.." && pwd)}"

BARE_HOME="${BARE_HOME:-/z/bare}"
WORKTREES_HOME="${WORKTREES_HOME:-/z/repos}"
USER_NAME="${USER_NAME:-${NAME:-Roberto Flores}}"
USER_EMAIL="${USER_EMAIL:-${EMAIL:-25asab015@ujmd.edu.sv}}"

export RUNTIME_DIR
export RAVN_GIT_BARE_CLONE_ROOT
export BARE_HOME
export WORKTREES_HOME
export USER_NAME
export USER_EMAIL
