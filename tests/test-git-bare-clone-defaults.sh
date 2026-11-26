#!/usr/bin/env bash
# Defaults of ravn-git-bare-clone point at the central root /z-home-repos:
# bare in /z-home-repos/.bare/<repo>.git, worktrees in /z-home-repos/repos/<repo>/<branch>.
# The real root is never touched: a mkdir stub records the first filesystem
# write the script attempts and refuses it.

set -euo pipefail

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gbc-test-defaults.XXXXXX")
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
BIN="$REPO_ROOT/ravn-wt"
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

mkdir -p "$FAKE_BIN" "$TEST_ROOT/home" "$TEST_ROOT/outside" "$TEST_ROOT/hr/nested/sub"
touch "$TEST_ROOT/hr/proyecto.yml"

cat > "$FAKE_BIN/mkdir" << 'EOF_STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MKDIR_LOG"
exit 1
EOF_STUB
chmod +x "$FAKE_BIN/mkdir"

# Help documents the central defaults.
env -u BARE_HOME -u WORKTREES_HOME HOME="$TEST_ROOT/home" \
  "$BIN" -h > "$TEST_ROOT/help.out" 2>&1 || true
grep -Fq '/z-home-repos/.bare/<repo>.git' "$TEST_ROOT/help.out" || fail "help does not show /z-home-repos/.bare/<repo>.git"
grep -Fq '/z-home-repos/repos/<repo>' "$TEST_ROOT/help.out" || fail "help does not show /z-home-repos/repos/<repo>"

# Also test 'clone -h'
env -u BARE_HOME -u WORKTREES_HOME HOME="$TEST_ROOT/home" \
  "$BIN" clone -h > "$TEST_ROOT/clone-help.out" 2>&1 || true
grep -Fq '/z-home-repos/.bare/<repo>.git' "$TEST_ROOT/clone-help.out" || fail "clone help does not show /z-home-repos/.bare/<repo>.git"
grep -Fq '/z-home-repos/repos/<repo>' "$TEST_ROOT/clone-help.out" || fail "clone help does not show /z-home-repos/repos/<repo>"
grep -Fq -- '-b, --bare-dir' "$TEST_ROOT/clone-help.out" || fail "clone help does not show -b, --bare-dir"

expected_root="/z-home-repos"
[[ -d "/z-home-repos" ]] || expected_root="$TEST_ROOT/home/z-home-repos"

# Without env vars, the first directories it creates are central .bare and repos.
if (cd "$TEST_ROOT/outside" && env -u BARE_HOME -u WORKTREES_HOME \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" robert-flo/alpha > "$TEST_ROOT/run.out" 2>&1); then
  fail "expected the mkdir stub to stop the run"
fi
[[ -s $MKDIR_LOG ]] || fail "ravn-git-bare-clone did not try to create its base directories"
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == "-p ${expected_root}/.bare ${expected_root}/repos" ]] ||
  fail "unexpected default directories: '$first_mkdir'"

# Also test with explicit 'clone' subcommand:
: > "$MKDIR_LOG"
if (cd "$TEST_ROOT/outside" && env -u BARE_HOME -u WORKTREES_HOME \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" clone robert-flo/alpha > "$TEST_ROOT/run2.out" 2>&1); then
  fail "expected the mkdir stub to stop the run"
fi
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == "-p ${expected_root}/.bare ${expected_root}/repos" ]] ||
  fail "unexpected default directories with clone subcommand: '$first_mkdir'"

# --group still overrides only the worktrees base; bare stays on the default.
: > "$MKDIR_LOG"
(cd "$TEST_ROOT/outside" && env -u BARE_HOME -u WORKTREES_HOME \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" --group /z-home-repos/repos/pj-demo robert-flo/alpha \
  > "$TEST_ROOT/group.out" 2>&1) || true
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == "-p ${expected_root}/.bare /z-home-repos/repos/pj-demo" ]] ||
  fail "unexpected --group directories: '$first_mkdir'"

# Inside a Home Repo (CWD has proyecto.yml), it uses the central root (no .bares local).
: > "$MKDIR_LOG"
(cd "$TEST_ROOT/hr" && env -u BARE_HOME -u WORKTREES_HOME \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" clone robert-flo/alpha > "$TEST_ROOT/hr-cwd.out" 2>&1) || true
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == "-p ${expected_root}/.bare ${expected_root}/repos" ]] ||
  fail "unexpected Home Repo directories from CWD: '$first_mkdir'"

# Inside a Home Repo subdirectory, still uses central root.
: > "$MKDIR_LOG"
(cd "$TEST_ROOT/hr/nested/sub" && env -u BARE_HOME -u WORKTREES_HOME \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" clone robert-flo/alpha > "$TEST_ROOT/hr-sub.out" 2>&1) || true
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == "-p ${expected_root}/.bare ${expected_root}/repos" ]] ||
  fail "unexpected Home Repo directories from subdirectory: '$first_mkdir'"

# Env vars BARE_HOME and WORKTREES_HOME override central root.
: > "$MKDIR_LOG"
(cd "$TEST_ROOT/hr/nested/sub" && env \
  BARE_HOME="/env/bare" WORKTREES_HOME="/env/repos" \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" clone robert-flo/alpha > "$TEST_ROOT/hr-env.out" 2>&1) || true
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == '-p /env/bare /env/repos' ]] ||
  fail "expected env vars to override central defaults: '$first_mkdir'"

# CLI flags -b/--bare-dir and -w/--worktrees-dir override both central defaults and env vars.
: > "$MKDIR_LOG"
(cd "$TEST_ROOT/hr/nested/sub" && env \
  BARE_HOME="/env/bare" WORKTREES_HOME="/env/repos" \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" clone -b /cli/bare -w /cli/repos robert-flo/alpha > "$TEST_ROOT/hr-cli.out" 2>&1) || true
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == '-p /cli/bare /cli/repos' ]] ||
  fail "expected -b and -w flags to override env: '$first_mkdir'"

# Long flags --bare-dir and --worktrees-dir also work.
: > "$MKDIR_LOG"
(cd "$TEST_ROOT/hr" && env -u BARE_HOME -u WORKTREES_HOME \
  PATH="$FAKE_BIN:$PATH" HOME="$TEST_ROOT/home" MKDIR_LOG="$MKDIR_LOG" \
  "$BIN" clone --bare-dir /long/bare --worktrees-dir /long/repos robert-flo/alpha > "$TEST_ROOT/hr-long.out" 2>&1) || true
read -r first_mkdir < "$MKDIR_LOG"
[[ $first_mkdir == '-p /long/bare /long/repos' ]] ||
  fail "expected --bare-dir and --worktrees-dir flags to override central root: '$first_mkdir'"

printf 'ravn-git-bare-clone central defaults: passed\n'
