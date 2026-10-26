#!/usr/bin/env bash
# Defaults of ravn-git-bare-clone point at the shared root /z (ADR-0009):
# bare in /z/bare/<repo>.git, worktrees in /z/repos/<repo>/<branch>.
# The real /z is never touched: a mkdir stub records the first filesystem
# write the script attempts and refuses it.

set -euo pipefail

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gbc-test-defaults.XXXXXX")
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
BIN="$REPO_ROOT/ravn-git-bare-clone"
readonly BIN
FAKE_BIN="$TEST_ROOT/bin"
readonly FAKE_BIN
MKDIR_LOG="$TEST_ROOT/mkdir.log"
readonly MKDIR_LOG

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

export GIT_AUTHOR_NAME="Test"
export GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Test"
export GIT_COMMITTER_EMAIL="test@example.com"

mkdir -p "$FAKE_BIN" "$TEST_ROOT/home"

cat > "$FAKE_BIN/mkdir" << 'EOF_STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MKDIR_LOG"
exit 1
EOF_STUB
chmod +x "$FAKE_BIN/mkdir"

# Help documents the new defaults.
env -u BARE_HOME -u WORKTREES_HOME HOME="$TEST_ROOT/home" \
  "$BIN" -h > "$TEST_ROOT/help.out" 2>&1 || true
grep -Fq '/z/bare/<repo>.git' "$TEST_ROOT/help.out" || fail "help does not show /z/bare/<repo>.git"
grep -Fq '/z/repos/<repo>' "$TEST_ROOT/help.out" || fail "help does not show /z/repos/<repo>"

# Also test 'clone -h'
env -u BARE_HOME -u WORKTREES_HOME HOME="$TEST_ROOT/home" \
  "$BIN" clone -h > "$TEST_ROOT/clone-help.out" 2>&1 || true
grep -Fq '/z/bare/<repo>.git' "$TEST_ROOT/clone-help.out" || fail "clone help does not show /z/bare/<repo>.git"
grep -Fq '/z/repos/<repo>' "$TEST_ROOT/clone-help.out" || fail "clone help does not show /z/repos/<repo>"

# Without env vars, the first directories it creates are /z/bare and /z/repos.
if env -u BARE_HOME -u WORKTREES_HOME \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" robert-flo/alpha > "$TEST_ROOT/run.out" 2>&1; then
  fail "expected the mkdir stub to stop the run"
fi
[[ -s $MKDIR_LOG ]] || fail "ravn-git-bare-clone did not try to create its base directories"
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == '-p /z/bare /z/repos' ]] ||
  fail "unexpected default directories: '$first_mkdir'"

# Also test with explicit 'clone' subcommand:
: > "$MKDIR_LOG"
if env -u BARE_HOME -u WORKTREES_HOME \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" clone robert-flo/alpha > "$TEST_ROOT/run2.out" 2>&1; then
  fail "expected the mkdir stub to stop the run"
fi
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == '-p /z/bare /z/repos' ]] ||
  fail "unexpected default directories with clone subcommand: '$first_mkdir'"

# --group still overrides only the worktrees base; bare stays on the default.
: > "$MKDIR_LOG"
env -u BARE_HOME -u WORKTREES_HOME \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" --group /z/repos/pj-demo robert-flo/alpha \
  > "$TEST_ROOT/group.out" 2>&1 || true
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == '-p /z/bare /z/repos/pj-demo' ]] ||
  fail "unexpected --group directories: '$first_mkdir'"

printf 'ravn-git-bare-clone defaults /z: passed\n'
