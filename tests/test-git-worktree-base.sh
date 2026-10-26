#!/usr/bin/env bash
# Real-git coverage: a new worktree starts from the repo's default branch
# (origin/HEAD), not from a hardcoded origin/main. The origin's default is
# master and it has no main branch. git-bare-clone records origin/HEAD.
# Worktrees for default branches are kept free in bare repositories.

set -euo pipefail

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gbc-test-wt-base.XXXXXX")
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

export HOME="$TEST_ROOT/home"
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME="Test"
export GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Test"
export GIT_COMMITTER_EMAIL="test@example.com"
export BARE_HOME="$TEST_ROOT/bare"
export WORKTREES_HOME="$TEST_ROOT/work"
mkdir -p "$HOME" "$TEST_ROOT/bin"

ORIGIN="$TEST_ROOT/demo.git"
SEED="$TEST_ROOT/seed"
git init -q --bare -b master "$ORIGIN"
git clone -q "$ORIGIN" "$SEED" 2> /dev/null
git -C "$SEED" config user.email "test@example.com"
git -C "$SEED" config user.name "Test"
git -C "$SEED" commit -q --allow-empty -m "init on master"
git -C "$SEED" push -q origin HEAD:master
git -C "$SEED" checkout -q -b dev
git -C "$SEED" commit -q --allow-empty -m "dev only"
git -C "$SEED" push -q origin dev
MASTER_SHA=$(git -C "$SEED" rev-parse master)
DEV_SHA=$(git -C "$SEED" rev-parse dev)

"$REPO_ROOT/bin/git-bare-clone" "$ORIGIN" > "$TEST_ROOT/clone.out" 2>&1 ||
  fail "git-bare-clone failed: $(cat "$TEST_ROOT/clone.out")"

BARE="$BARE_HOME/demo.git"
[[ $(git --git-dir="$BARE" symbolic-ref refs/remotes/origin/HEAD) == refs/remotes/origin/master ]] ||
  fail "git-bare-clone did not record origin/HEAD -> origin/master"

# Sync mode also records it (bares cloned before this change lack it).
git --git-dir="$BARE" symbolic-ref --delete refs/remotes/origin/HEAD
"$REPO_ROOT/bin/git-bare-clone" "$ORIGIN" > "$TEST_ROOT/sync.out" 2>&1 ||
  fail "git-bare-clone sync failed: $(cat "$TEST_ROOT/sync.out")"
git --git-dir="$BARE" rev-parse --verify -q origin/HEAD > /dev/null ||
  fail "git-bare-clone sync did not restore origin/HEAD"

WT_ROOT="$WORKTREES_HOME/demo"

# Default branch (master) must not have an automatic worktree
[[ ! -e "$WT_ROOT/master" ]] || fail "master worktree should be kept free"
[[ -d "$WT_ROOT/dev" ]] || fail "dev worktree should exist"

# git-create-worktree without -B: starts at the default branch (master).
(cd "$WT_ROOT/dev" && "$REPO_ROOT/bin/git-create-worktree" -N -p "" feat) \
  > "$TEST_ROOT/create.out" 2>&1 || fail "git-create-worktree failed: $(cat "$TEST_ROOT/create.out")"
[[ $(git -C "$WT_ROOT/feat" rev-parse HEAD) == "$MASTER_SHA" ]] ||
  fail "default base is not the repo's default branch"
grep -Fq 'Repository: demo' <(sed 's/\x1b\[[0-9;]*m//g' "$TEST_ROOT/create.out") ||
  fail "repository name should not carry the .git suffix"

# -B still wins.
(cd "$WT_ROOT/dev" && "$REPO_ROOT/bin/git-create-worktree" -N -p "" -B origin/dev from-dev) \
  > "$TEST_ROOT/create-dev.out" 2>&1 || fail "git-create-worktree -B failed"
[[ $(git -C "$WT_ROOT/from-dev" rev-parse HEAD) == "$DEV_SHA" ]] ||
  fail "-B origin/dev was not honoured"

# git-issue-worktree without -B: also the default branch, no prefix.
cat > "$TEST_ROOT/bin/gh" << 'EOF_GH'
#!/usr/bin/env bash
if [[ $1 == issue && $2 == view ]]; then
  printf '{"number":%s,"title":"Demo issue","state":"OPEN"}\n' "$3"
  exit 0
fi
exit 1
EOF_GH
chmod +x "$TEST_ROOT/bin/gh"
(cd "$WT_ROOT/dev" && PATH="$TEST_ROOT/bin:$PATH" "$REPO_ROOT/bin/git-issue-worktree" 42 demo) \
  > "$TEST_ROOT/issue.out" 2>&1 || fail "git-issue-worktree failed: $(cat "$TEST_ROOT/issue.out")"
[[ $(git -C "$WT_ROOT/42-demo" rev-parse HEAD) == "$MASTER_SHA" ]] ||
  fail "git-issue-worktree default base is not the repo's default branch"
[[ $(git -C "$WT_ROOT/42-demo" branch --show-current) == issue/42-demo ]] ||
  fail "git-issue-worktree branch should be issue/42-demo (empty prefix)"

# An empty remote has no default branch: warn, do not fail.
git init -q --bare "$TEST_ROOT/empty.git"
"$REPO_ROOT/bin/git-bare-clone" "$TEST_ROOT/empty.git" > "$TEST_ROOT/empty.out" 2>&1 ||
  fail "git-bare-clone must not fail on an empty remote"
grep -Fq 'origin/HEAD not set' "$TEST_ROOT/empty.out" || fail "missing origin/HEAD warning"

# Without origin/HEAD the default base must fail loudly: clear message, and
# neither the branch nor the worktree may be created.
git --git-dir="$BARE" symbolic-ref --delete refs/remotes/origin/HEAD
(cd "$WT_ROOT/dev" && "$REPO_ROOT/bin/git-create-worktree" -N -p "" no-head) \
  > "$TEST_ROOT/no-head.out" 2>&1 && fail "git-create-worktree must fail without origin/HEAD"
grep -Fq 'origin/HEAD is not set' "$TEST_ROOT/no-head.out" || fail "missing origin/HEAD guard message"
if git --git-dir="$BARE" rev-parse --verify -q refs/heads/no-head >/dev/null; then
  fail "branch must not be created without origin/HEAD"
fi
if [[ -e "$WT_ROOT/no-head" ]]; then
  fail "worktree must not be created without origin/HEAD"
fi

# die() comes from global_fn.sh: an unknown option must exit 1 with a
# message, not 127 (command not found).
set +e
(cd "$WT_ROOT/dev" && "$REPO_ROOT/bin/git-create-worktree" -Z bogus) \
  > "$TEST_ROOT/die.out" 2>&1
die_rc=$?
set -e
[[ $die_rc -eq 1 ]] || fail "unknown option must exit 1, got $die_rc (127 means die is undefined)"
grep -Fq 'Unknown option' "$TEST_ROOT/die.out" || fail "missing die message"

printf 'worktree base origin/HEAD: passed\n'
