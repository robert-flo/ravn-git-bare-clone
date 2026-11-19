#!/usr/bin/env bash
# Real-git coverage: ravn-wt sync and ravn-wt clone prune orphan remote refs,
# clean orphan worktrees (including squash-merged branches and empty parent
# directories), and bare-only orphan branches while protecting dirty, locked,
# current-dir, outside-root, local-only, origin/HEAD, and active worktrees.

set -euo pipefail

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gbc-test-prune.XXXXXX")
readonly TEST_ROOT
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
BIN="$REPO_ROOT/ravn-wt"
readonly BIN

ORIGIN="$TEST_ROOT/origin.git"
readonly ORIGIN
BARE_HOME="$TEST_ROOT/bare"
readonly BARE_HOME
WORK_HOME="$TEST_ROOT/work"
readonly WORK_HOME
SEED="$TEST_ROOT/seed"
readonly SEED
OUTSIDE_WT="$TEST_ROOT/outside-wt"
readonly OUTSIDE_WT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Isolate git environment from developer global configs (no fetch.prune=true)
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
printf 'master-v1\n' > "$SEED/README"
git -C "$SEED" add README
git -C "$SEED" commit -m "init on master" > /dev/null
git -C "$SEED" branch -M master
git -C "$SEED" push -u origin master > /dev/null 2>&1

create_remote_branch() {
  local name=$1
  local content=$2

  git -C "$SEED" checkout -B "$name" master > /dev/null 2>&1
  printf '%s\n' "$content" > "$SEED/${name//\//_}.txt"
  git -C "$SEED" add .
  git -C "$SEED" commit -m "commit on $name" > /dev/null
  git -C "$SEED" push -u origin "$name" > /dev/null 2>&1
}

# Branches that will be deleted on origin later
create_remote_branch "merged-clean" "merged"
create_remote_branch "squash-merged" "squash"
create_remote_branch "fix/only-child/gone" "fix-gone"
create_remote_branch "feat/nested/gone" "feat-gone"
create_remote_branch "bare-only-gone" "bare-gone"
create_remote_branch "dirty-mod" "dirty-mod"
create_remote_branch "dirty-untracked" "dirty-untracked"
create_remote_branch "locked-gone" "locked"
create_remote_branch "cwd-gone" "cwd"
create_remote_branch "outside-gone" "outside"
create_remote_branch "stale-dir-gone" "stale-dir"

# Branches that stay on origin
create_remote_branch "feat/nested/active" "feat-active"
create_remote_branch "active-keep" "active-v1"

export BARE_HOME WORKTREES_HOME="$WORK_HOME"
export HOME="$TEST_ROOT/home"
mkdir -p "$HOME"

# Initial clone creates bare + all remote branch worktrees
"$BIN" clone "$ORIGIN" > "$TEST_ROOT/initial.out"

REPO_NAME="origin"
BARE_DIR="$BARE_HOME/$REPO_NAME.git"
WORK_DIR="$WORK_HOME/$REPO_NAME"

# Record active-keep HEAD before origin advances
ACTIVE_HEAD_BEFORE="$(git -C "$WORK_DIR/active-keep" rev-parse HEAD)"

# Make bare-only-gone a bare-only local branch (remove its worktree, keep ref)
git -C "$WORK_DIR" worktree remove "$WORK_DIR/bare-only-gone"

# Move outside-gone worktree outside $WORK_DIR
git -C "$WORK_DIR" worktree remove "$WORK_DIR/outside-gone"
git -C "$WORK_DIR" worktree add "$OUTSIDE_WT" "outside-gone" > /dev/null 2>&1

# Create a purely local branch (no upstream) with a worktree
git -C "$WORK_DIR" worktree add -b "local-only" "$WORK_DIR/local-only" master > /dev/null 2>&1

# Dirty (modified tracked file)
printf 'uncommitted change\n' >> "$WORK_DIR/dirty-mod/dirty-mod.txt"

# Dirty (untracked file)
printf 'untracked file\n' > "$WORK_DIR/dirty-untracked/new.txt"

# Locked worktree
git -C "$WORK_DIR" worktree lock --reason "in use" "$WORK_DIR/locked-gone"

# Subdir inside cwd-gone to test invoking from inside a nested directory
mkdir -p "$WORK_DIR/cwd-gone/subdir"

# Manually delete stale-dir-gone directory to leave a prunable worktree entry
rm -rf "$WORK_DIR/stale-dir-gone"

# On origin:
# - Merge merged-clean into master (normal ancestor)
git -C "$SEED" checkout master > /dev/null 2>&1
git -C "$SEED" merge --no-ff merged-clean -m "merge merged-clean" > /dev/null 2>&1
# - Squash-merge squash-merged into master (commit on squash-merged is NOT ancestor of master)
git -C "$SEED" merge --squash squash-merged > /dev/null 2>&1
git -C "$SEED" commit -m "squash squash-merged" > /dev/null
git -C "$SEED" push origin master > /dev/null 2>&1

# - Advance active-keep on origin (local worktree HEAD must stay untouched)
git -C "$SEED" checkout active-keep > /dev/null 2>&1
printf 'active-v2\n' >> "$SEED/active-keep.txt"
git -C "$SEED" commit -am "advance active-keep" > /dev/null
git -C "$SEED" push origin active-keep > /dev/null 2>&1

# - Delete all gone branches on origin
for gone in \
  merged-clean \
  squash-merged \
  fix/only-child/gone \
  feat/nested/gone \
  bare-only-gone \
  dirty-mod \
  dirty-untracked \
  locked-gone \
  cwd-gone \
  outside-gone \
  stale-dir-gone; do
  git -C "$SEED" push origin --delete "$gone" > /dev/null 2>&1
done

# Run ravn-wt sync from inside cwd-gone/subdir to trigger current-dir guard
(
  cd "$WORK_DIR/cwd-gone/subdir"
  "$BIN" sync "$ORIGIN"
) > "$TEST_ROOT/sync.out" 2>&1

# 1. Remote tracking refs for deleted branches must be pruned even with GIT_CONFIG_GLOBAL=/dev/null
for gone in merged-clean squash-merged fix/only-child/gone feat/nested/gone bare-only-gone; do
  if git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/remotes/origin/$gone"; then
    fail "remote tracking ref origin/$gone should have been pruned"
  fi
done

# 2. Clean orphan worktrees & branches (including squash-merged) must be removed
for pruned in merged-clean squash-merged fix/only-child/gone feat/nested/gone stale-dir-gone; do
  [[ ! -e "$WORK_DIR/$pruned" ]] || fail "orphan worktree $pruned should have been removed"
  if git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/$pruned"; then
    fail "orphan local branch $pruned should have been deleted"
  fi
done

# 3. Bare-only orphan branch must be deleted
if git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/bare-only-gone"; then
  fail "bare-only orphan branch bare-only-gone should have been deleted"
fi

# 4. Empty parent directories removed strictly inside $WORK_DIR; $WORK_DIR and sibling dirs kept
[[ -d "$WORK_DIR" ]] || fail "worktrees root $WORK_DIR must never be deleted"
[[ ! -e "$WORK_DIR/fix/only-child" ]] || fail "empty parent dir fix/only-child should be removed"
[[ ! -e "$WORK_DIR/fix" ]] || fail "empty parent dir fix should be removed"
[[ -d "$WORK_DIR/feat/nested/active" ]] || fail "sibling active worktree feat/nested/active must remain"

# 5. Guards: dirty, locked, current-dir, outside-root must be skipped with visible warning
[[ -d "$WORK_DIR/dirty-mod" ]] || fail "dirty-mod worktree must not be removed"
grep -q "uncommitted change" "$WORK_DIR/dirty-mod/dirty-mod.txt" || fail "dirty-mod edits lost"
git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/dirty-mod" || fail "dirty-mod branch must remain"
grep -E "dirty-mod.*dirty" "$TEST_ROOT/sync.out" > /dev/null || fail "missing dirty warning for dirty-mod"

[[ -d "$WORK_DIR/dirty-untracked" ]] || fail "dirty-untracked worktree must not be removed"
[[ -f "$WORK_DIR/dirty-untracked/new.txt" ]] || fail "dirty-untracked file lost"
git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/dirty-untracked" || fail "dirty-untracked branch must remain"
grep -E "dirty-untracked.*dirty" "$TEST_ROOT/sync.out" > /dev/null || fail "missing dirty warning for dirty-untracked"

[[ -d "$WORK_DIR/locked-gone" ]] || fail "locked-gone worktree must not be removed"
git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/locked-gone" || fail "locked-gone branch must remain"
grep -E "locked-gone.*locked" "$TEST_ROOT/sync.out" > /dev/null || fail "missing locked warning for locked-gone"

[[ -d "$WORK_DIR/cwd-gone/subdir" ]] || fail "cwd-gone worktree must not be removed"
git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/cwd-gone" || fail "cwd-gone branch must remain"
grep -E "cwd-gone.*current-dir" "$TEST_ROOT/sync.out" > /dev/null || fail "missing current-dir warning for cwd-gone"

[[ -d "$OUTSIDE_WT" ]] || fail "outside-gone worktree must not be removed"
git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/outside-gone" || fail "outside-gone branch must remain"
grep -E "outside-gone.*outside" "$TEST_ROOT/sync.out" > /dev/null || fail "missing outside warning for outside-gone"

# 6. Local-only branch (no upstream), origin/HEAD (master), and active worktrees intact
[[ -d "$WORK_DIR/local-only" ]] || fail "local-only worktree must remain"
git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/local-only" || fail "local-only branch must remain"

[[ -d "$WORK_DIR/master" ]] || fail "master worktree must remain"
git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/master" || fail "master branch must remain"

[[ -d "$WORK_DIR/active-keep" ]] || fail "active-keep worktree must remain"
ACTIVE_HEAD_AFTER="$(git -C "$WORK_DIR/active-keep" rev-parse HEAD)"
[[ "$ACTIVE_HEAD_BEFORE" == "$ACTIVE_HEAD_AFTER" ]] ||
  fail "active-keep HEAD must not move on sync ($ACTIVE_HEAD_BEFORE != $ACTIVE_HEAD_AFTER)"

# 7. Administrative git worktree prune ran (no prunable entries remain)
if git --git-dir="$BARE_DIR" worktree list --porcelain | grep -q '^prunable'; then
  fail "prunable worktree entries should have been cleaned by git worktree prune"
fi

# 8. Also verify re-running via `ravn-wt clone` prunes once guards are cleared
git -C "$WORK_DIR" worktree unlock "$WORK_DIR/locked-gone"
"$BIN" clone "$ORIGIN" > "$TEST_ROOT/clone-resync.out" 2>&1
[[ ! -e "$WORK_DIR/locked-gone" ]] || fail "unlocked locked-gone should be pruned on ravn-wt clone"
if git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/locked-gone"; then
  fail "unlocked locked-gone branch should be deleted on ravn-wt clone"
fi
# Running from outside cwd-gone should now prune cwd-gone as well
[[ ! -e "$WORK_DIR/cwd-gone" ]] || fail "cwd-gone should be pruned when invoked outside it"
if git --git-dir="$BARE_DIR" show-ref --verify --quiet "refs/heads/cwd-gone"; then
  fail "cwd-gone branch should be deleted when invoked outside it"
fi

printf 'ravn-git-bare-clone prune orphan worktrees: passed\n'
