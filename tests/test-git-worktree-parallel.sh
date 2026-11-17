#!/usr/bin/env bash
# Parallel worktrees and default branch (master) worktree creation test.
#
# Validates:
# 1. ravn-git-bare-clone clone creates worktrees for all remote branches, including origin/HEAD (master).
# 2. Multiple worktrees (e.g. agent-1 and agent-2) can be created from origin/HEAD and operate concurrently.
# 3. Worktrees operate independently without cross-interference on commits/files.
# 4. Duplicate checkout of master fails with git's already checked out error.

set -euo pipefail

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gbc-test-wt-parallel.XXXXXX")
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

export HOME="$TEST_ROOT/home"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME="Test"
export GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Test"
export GIT_COMMITTER_EMAIL="test@example.com"
export BARE_HOME="$TEST_ROOT/bare"
export WORKTREES_HOME="$TEST_ROOT/work"
mkdir -p "$HOME" "$TEST_ROOT/bin"

# 1. Setup mock remote repository with master and dev branches
ORIGIN="$TEST_ROOT/demo.git"
SEED="$TEST_ROOT/seed"
git init -q --bare -b master "$ORIGIN"
git clone -q "$ORIGIN" "$SEED" 2>/dev/null
git -C "$SEED" config user.email "test@example.com"
git -C "$SEED" config user.name "Test"
echo "initial master content" > "$SEED/README.md"
git -C "$SEED" add README.md
git -C "$SEED" commit -q -m "init on master"
git -C "$SEED" push -q origin HEAD:master
git -C "$SEED" checkout -q -b dev
echo "dev content" > "$SEED/dev.txt"
git -C "$SEED" add dev.txt
git -C "$SEED" commit -q -m "dev branch commit"
git -C "$SEED" push -q origin dev

MASTER_SHA=$(git -C "$SEED" rev-parse master)
readonly MASTER_SHA

# 2. Clone bare repository via ravn-git-bare-clone clone
"$REPO_ROOT/ravn-wt" clone "$ORIGIN" > "$TEST_ROOT/clone.out" 2>&1 ||
  fail "ravn-wt clone failed: $(cat "$TEST_ROOT/clone.out")"

BARE="$BARE_HOME/demo.git"
WT_ROOT="$WORKTREES_HOME/demo"

# Verify origin/HEAD is set to refs/remotes/origin/master
[[ $(git --git-dir="$BARE" symbolic-ref refs/remotes/origin/HEAD) == refs/remotes/origin/master ]] ||
  fail "origin/HEAD not set to origin/master"

# 3. Verify that both master and dev have automatic worktrees
[[ -d "$WT_ROOT/master" ]] || fail "master worktree should exist"
[[ -d "$WT_ROOT/dev" ]] || fail "dev worktree should exist"
[[ $(git -C "$WT_ROOT/master" branch --show-current) == "master" ]] ||
  fail "master worktree is not on master branch"
[[ $(git -C "$WT_ROOT/master" rev-parse HEAD) == "$MASTER_SHA" ]] ||
  fail "master worktree SHA does not match initial master SHA"

# 4. Create two worktrees in parallel (agent-1 and agent-2) using ravn-wt create
(cd "$WT_ROOT/dev" && "$REPO_ROOT/ravn-wt" create -N -p "" agent-1) \
  > "$TEST_ROOT/create-agent-1.out" 2>&1 || fail "create agent-1 failed: $(cat "$TEST_ROOT/create-agent-1.out")"

(cd "$WT_ROOT/dev" && "$REPO_ROOT/ravn-wt" create -N -p "" agent-2) \
  > "$TEST_ROOT/create-agent-2.out" 2>&1 || fail "create agent-2 failed: $(cat "$TEST_ROOT/create-agent-2.out")"

[[ -d "$WT_ROOT/agent-1" ]] || fail "agent-1 worktree directory missing"
[[ -d "$WT_ROOT/agent-2" ]] || fail "agent-2 worktree directory missing"

# Both start from master (origin/HEAD)
[[ $(git -C "$WT_ROOT/agent-1" rev-parse HEAD) == "$MASTER_SHA" ]] ||
  fail "agent-1 did not start from master HEAD"
[[ $(git -C "$WT_ROOT/agent-2" rev-parse HEAD) == "$MASTER_SHA" ]] ||
  fail "agent-2 did not start from master HEAD"

# 5. Confirm that both worktrees operate independently and simultaneously
echo "change by agent 1" > "$WT_ROOT/agent-1/agent1.txt"
git -C "$WT_ROOT/agent-1" add agent1.txt
git -C "$WT_ROOT/agent-1" commit -q -m "commit in agent-1"

echo "change by agent 2" > "$WT_ROOT/agent-2/agent2.txt"
git -C "$WT_ROOT/agent-2" add agent2.txt
git -C "$WT_ROOT/agent-2" commit -q -m "commit in agent-2"

[[ -f "$WT_ROOT/agent-1/agent1.txt" ]] || fail "agent1.txt missing in agent-1"
[[ ! -f "$WT_ROOT/agent-2/agent1.txt" ]] || fail "agent1.txt leaked to agent-2"
[[ -f "$WT_ROOT/agent-2/agent2.txt" ]] || fail "agent2.txt missing in agent-2"
[[ ! -f "$WT_ROOT/agent-1/agent2.txt" ]] || fail "agent2.txt leaked to agent-1"

# 6. Confirm independent work on master works smoothly
echo "master update" >> "$WT_ROOT/master/README.md"
git -C "$WT_ROOT/master" commit -q -am "update directly on master"

# Finally, demonstrate that attempting to checkout master again in a second worktree
# triggers git's collision error.
if git -C "$BARE" worktree add "$WT_ROOT/master-duplicate" master > "$TEST_ROOT/collision.out" 2>&1; then
  fail "duplicate checkout of master should have failed with fatal collision error"
fi
grep -Eq "already (used by worktree|checked out)" "$TEST_ROOT/collision.out" ||
  fail "expected 'already used by worktree' or 'already checked out' in error output: $(cat "$TEST_ROOT/collision.out")"

printf 'parallel worktrees and master worktree: passed\n'
