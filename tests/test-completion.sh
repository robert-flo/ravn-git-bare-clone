#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gbc-completion-test.XXXXXX")"

trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_output() {
  grep -Fqx -- "$2" "$1" || fail "missing completion entry: $2"
}

BASH_OUTPUT="$TEST_ROOT/bash-output"
bash -c '
  set -Eeuo pipefail
  source "$1/runtime/completion/git-bare-clone.bash"
  COMP_WORDS=(ravn-git-bare-clone "")
  COMP_CWORD=1
  _git_bare_clone_completion
  printf "%s\n" "${COMPREPLY[@]}"
' _ "$ROOT_DIR" > "$BASH_OUTPUT"

for command in clone sync create issue help; do
  require_output "$BASH_OUTPUT" "$command"
done
for alias in c --clone -c s --sync -s cr --create i --issue h --help -h; do
  require_output "$BASH_OUTPUT" "$alias"
done

# Test options completion for subcommands
bash -c '
  set -Eeuo pipefail
  source "$1/runtime/completion/git-bare-clone.bash"
  COMP_WORDS=(ravn-git-bare-clone clone "")
  COMP_CWORD=2
  _git_bare_clone_completion
  printf "%s\n" "${COMPREPLY[@]}"
' _ "$ROOT_DIR" > "$TEST_ROOT/bash-clone-opts"
require_output "$TEST_ROOT/bash-clone-opts" '-h'
require_output "$TEST_ROOT/bash-clone-opts" '--help'
require_output "$TEST_ROOT/bash-clone-opts" '-w'
require_output "$TEST_ROOT/bash-clone-opts" '--group'

bash -c '
  set -Eeuo pipefail
  source "$1/runtime/completion/git-bare-clone.bash"
  COMP_WORDS=(git-bare-clone create "")
  COMP_CWORD=2
  _git_bare_clone_completion
  printf "%s\n" "${COMPREPLY[@]}"
' _ "$ROOT_DIR" > "$TEST_ROOT/bash-create-opts"
require_output "$TEST_ROOT/bash-create-opts" '-b'
require_output "$TEST_ROOT/bash-create-opts" '-B'
require_output "$TEST_ROOT/bash-create-opts" '-N'

# Sourcing completion must not create or modify home config
mkdir -p "$TEST_ROOT/home"
HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/home/.config" \
  bash -c 'source "$1/runtime/completion/git-bare-clone.bash"' _ "$ROOT_DIR"
[[ ! -e $TEST_ROOT/home/.config ]] || fail 'Bash completion created configuration state'

# Test Zsh completion if zsh is available
if command -v zsh > /dev/null 2>&1; then
  zsh -n "$ROOT_DIR/runtime/completion/_git-bare-clone"

  zsh -fc '
    CURRENT=2
    _describe() {
      print -r -- "describe:$1"
      print -rC1 -- "${(@P)2}"
    }
    _arguments() { print -r -- "arguments:$*"; }
    source "$1"
  ' _ "$ROOT_DIR/runtime/completion/_git-bare-clone" > "$TEST_ROOT/zsh-commands-output"
  grep -Fqx 'describe:ravn-git-bare-clone command' "$TEST_ROOT/zsh-commands-output" ||
    fail 'Zsh completion did not describe commands'
  grep -Fq 'clone:Clone bare repo' "$TEST_ROOT/zsh-commands-output" ||
    fail 'Zsh completion did not describe clone'

  zsh -fc '
    CURRENT=3
    words=(ravn-git-bare-clone clone "")
    _describe() { print -r -- "unexpected describe call"; }
    _arguments() { print -r -- "arguments:$*"; }
    source "$1"
  ' _ "$ROOT_DIR/runtime/completion/_git-bare-clone" > "$TEST_ROOT/zsh-options-output"
  grep -Fq -- '-w --worktrees-dir --group' "$TEST_ROOT/zsh-options-output" ||
    fail 'Zsh completion did not suggest clone options'
else
  printf 'SKIP: zsh is unavailable; syntax check not run\n'
fi

printf 'PASS: Bash and Zsh completion contracts are valid\n'
