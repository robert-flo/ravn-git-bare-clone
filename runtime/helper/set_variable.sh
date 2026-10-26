#!/usr/bin/env bash

# Shared repository, runtime, and default worktree/bare configuration paths.
helper_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RUNTIME_DIR="${RUNTIME_DIR:-$(cd "$helper_dir/.." && pwd)}"
readonly RAVN_GIT_BARE_CLONE_ROOT="${RAVN_GIT_BARE_CLONE_ROOT:-$(cd "$RUNTIME_DIR/.." && pwd)}"

BARE_HOME="${BARE_HOME:-/z/bare}"
WORKTREES_HOME="${WORKTREES_HOME:-/z/repos}"

USER_NAME="${USER_NAME:-${GIT_AUTHOR_NAME:-${NAME:-}}}"
if [[ -z "$USER_NAME" ]]; then
  USER_NAME="$(git config user.name 2>/dev/null || true)"
fi
if [[ -z "$USER_NAME" ]]; then
  echo "Error: user.name is not configured in environment or git config. Please set git config user.name." >&2
  exit 1
fi

USER_EMAIL="${USER_EMAIL:-${GIT_AUTHOR_EMAIL:-${EMAIL:-}}}"
if [[ -z "$USER_EMAIL" ]]; then
  USER_EMAIL="$(git config user.email 2>/dev/null || true)"
fi
if [[ -z "$USER_EMAIL" ]]; then
  echo "Error: user.email is not configured in environment or git config. Please set git config user.email." >&2
  exit 1
fi

export RUNTIME_DIR
export RAVN_GIT_BARE_CLONE_ROOT
export BARE_HOME
export WORKTREES_HOME
export USER_NAME
export USER_EMAIL
