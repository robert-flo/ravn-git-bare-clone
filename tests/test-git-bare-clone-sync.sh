#!/usr/bin/env bash
# Real-git coverage: re-running ravn-git-bare-clone creates worktrees for remote
# branches that appeared after the initial clone.

set -euo pipefail

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gbc-test-sync.XXXXXX")
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
BIN="$REPO_ROOT/ravn-git-bare-clone"
readonly BIN

ORIGIN="$TEST_ROOT/origin.git"
readonly ORIGIN
BARE_HOME="$TEST_ROOT/bare"
readonly BARE_HOME
WORK_HOME="$TEST_ROOT/work"
readonly WORK_HOME
SEED="$TEST_ROOT/seed"
readonly SEED

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Isolate git environment from developer global configs (e.g. gpg/ssh signing)
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME="Test"
export GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Test"
export GIT_COMMITTER_EMAIL="test@example.com"

git init --bare "$ORIGIN" > /dev/null
git clone "$ORIGIN" "$SEED" > /dev/null 2>&1
git -C "$SEED" config user.email "test@example.com"
git -C "$SEED" config user.name "Test"
git -C "$SEED" config commit.gpgsign false
printf 'master\n' > "$SEED/README"
git -C "$SEED" add README
git -C "$SEED" commit -m "init on master" > /dev/null
git -C "$SEED" branch -M master
git -C "$SEED" push -u origin master > /dev/null 2>&1

export BARE_HOME WORKTREES_HOME="$WORK_HOME"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

"$BIN" "$ORIGIN" > "$TEST_ROOT/first.out"

# basename(origin.git) with .git stripped → origin; the bare keeps .git
REPO_NAME="origin"
[[ -d $BARE_HOME/$REPO_NAME.git ]] || fail "bare not created under $BARE_HOME"
[[ -d $WORK_HOME/$REPO_NAME/master ]] || fail "master worktree missing after first clone"
[[ ! -e $WORK_HOME/$REPO_NAME.git ]] || fail "worktrees folder must not carry the .git suffix"
[[ $(< "$WORK_HOME/$REPO_NAME/.git") == "gitdir: $(realpath "$BARE_HOME")/$REPO_NAME.git" ]] ||
  fail "worktrees root .git does not point to $REPO_NAME.git"
[[ ! -e $WORK_HOME/$REPO_NAME/dev ]] || fail "dev worktree should not exist yet"
[[ ! -e $WORK_HOME/$REPO_NAME/rc ]] || fail "rc worktree should not exist yet"

# Publish new remote branches after the initial bare clone
git -C "$SEED" checkout -b dev > /dev/null 2>&1
printf 'dev\n' > "$SEED/README"
git -C "$SEED" commit -am "dev branch" > /dev/null
git -C "$SEED" push -u origin dev > /dev/null 2>&1

git -C "$SEED" checkout -b rc > /dev/null 2>&1
printf 'rc\n' > "$SEED/README"
git -C "$SEED" commit -am "rc branch" > /dev/null
git -C "$SEED" push -u origin rc > /dev/null 2>&1

"$BIN" clone "$ORIGIN" > "$TEST_ROOT/second.out"

[[ -d $WORK_HOME/$REPO_NAME/master ]] || fail "master worktree lost after sync"
[[ -d $WORK_HOME/$REPO_NAME/dev ]] || fail "dev worktree not created on sync"
[[ -d $WORK_HOME/$REPO_NAME/rc ]] || fail "rc worktree not created on sync"

# Idempotent: third run creates nothing new and keeps existing worktrees
"$BIN" "$ORIGIN" > "$TEST_ROOT/third.out"
[[ -d $WORK_HOME/$REPO_NAME/master ]] || fail "master worktree lost after third run"
[[ -d $WORK_HOME/$REPO_NAME/dev ]] || fail "dev worktree lost after third run"
[[ -d $WORK_HOME/$REPO_NAME/rc ]] || fail "rc worktree lost after third run"

grep -Eiq 'No new worktrees needed|Already present' "$TEST_ROOT/third.out" ||
  fail "third run should report no new worktrees needed"

printf 'ravn-git-bare-clone sync missing branches: passed\n'
