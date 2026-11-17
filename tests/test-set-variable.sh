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

run_set_variable() {
  local workdir=$1
  shift
  (
    cd "$workdir" &&
      env -i PATH="$PATH" HOME="$TEST_ROOT/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
        USER_NAME="Alice" USER_EMAIL="alice@example.com" "$@" \
        bash -s "$REPO_ROOT" << 'EOF'
source "$1/runtime/helper/set_variable.sh"
printf '%s|%s\n' "$BARE_HOME" "$WORKTREES_HOME"
EOF
  )
}

# Test 4: Outside a Home Repo, defaults to /z/bare and /z/repos
output=$(run_set_variable "$TEST_ROOT/empty")
[[ "$output" == "/z/bare|/z/repos" ]] || fail "expected /z/bare|/z/repos outside Home Repo, got: $output"

# Test 5: Inside a Home Repo (proyecto.yml in CWD), uses .bares and repos
mkdir -p "$TEST_ROOT/hr/nested/sub"
touch "$TEST_ROOT/hr/proyecto.yml"
output=$(run_set_variable "$TEST_ROOT/hr")
[[ "$output" == "$TEST_ROOT/hr/.bares|$TEST_ROOT/hr/repos" ]] ||
  fail "expected Home Repo paths from CWD, got: $output"

# Test 6: Inside a subdirectory of a Home Repo, walks up to proyecto.yml
output=$(run_set_variable "$TEST_ROOT/hr/nested/sub")
[[ "$output" == "$TEST_ROOT/hr/.bares|$TEST_ROOT/hr/repos" ]] ||
  fail "expected Home Repo paths from subdirectory, got: $output"

# Test 7: Explicit env vars take precedence over Home Repo auto-detection
output=$(run_set_variable "$TEST_ROOT/hr/nested/sub" BARE_HOME="/custom/bare" WORKTREES_HOME="/custom/repos")
[[ "$output" == "/custom/bare|/custom/repos" ]] ||
  fail "expected explicit env vars to win over Home Repo, got: $output"

# Test 8: Partial env override keeps explicit var and auto-detects the other
output=$(run_set_variable "$TEST_ROOT/hr/nested/sub" BARE_HOME="/custom/bare")
[[ "$output" == "/custom/bare|$TEST_ROOT/hr/repos" ]] ||
  fail "expected partial override (BARE_HOME only) to keep BARE_HOME and auto-detect WORKTREES_HOME, got: $output"

printf 'set_variable.sh validation contract: passed\n'
