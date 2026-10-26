#!/usr/bin/env bash
# Test that set_variable.sh requires user.name and user.email (no hardcoded fallbacks).

set -euo pipefail

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gbc-test-set-var.XXXXXX")
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$TEST_ROOT/empty" "$TEST_ROOT/home"

# Test 1: Missing user.name and user.email must fail with descriptive error
set +e
output=$(
  cd "$TEST_ROOT/empty" && \
  env -i PATH="$PATH" HOME="$TEST_ROOT/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    bash -c 'source "'"$REPO_ROOT"'/runtime/helper/set_variable.sh"' 2>&1
)
rc=$?
set -e

[[ $rc -ne 0 ]] || fail "set_variable.sh should fail when user.name/email are not configured"
echo "$output" | grep -qi "user.name" || fail "error message should mention user.name: $output"

# Test 2: When user.name is provided but user.email is missing, fails on user.email
set +e
output=$(
  cd "$TEST_ROOT/empty" && \
  env -i PATH="$PATH" HOME="$TEST_ROOT/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    USER_NAME="Alice" \
    bash -c 'source "'"$REPO_ROOT"'/runtime/helper/set_variable.sh"' 2>&1
)
rc=$?
set -e

[[ $rc -ne 0 ]] || fail "set_variable.sh should fail when user.email is not configured"
echo "$output" | grep -qi "user.email" || fail "error message should mention user.email: $output"

# Test 3: When both are configured via environment or git config, succeeds
set +e
output=$(
  cd "$TEST_ROOT/empty" && \
  env -i PATH="$PATH" HOME="$TEST_ROOT/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    USER_NAME="Alice" USER_EMAIL="alice@example.com" \
    bash -c 'source "'"$REPO_ROOT"'/runtime/helper/set_variable.sh" && echo OK' 2>&1
)
rc=$?
set -e

[[ $rc -eq 0 ]] || fail "set_variable.sh should succeed with USER_NAME and USER_EMAIL set: $output"
[[ "$output" == *"OK"* ]] || fail "expected OK from successful source: $output"

printf 'set_variable.sh validation contract: passed\n'
