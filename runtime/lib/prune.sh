#!/usr/bin/env bash
# Safe pruning of orphan local branches and worktrees whose origin/* upstream
# no longer exists.

if [[ ${_PRUNE_SOURCED:-0} -eq 1 ]]; then
  # shellcheck disable=SC2317
  return 0 2> /dev/null || exit 0
fi
readonly _PRUNE_SOURCED=1

# Remove empty parent directories strictly inside $root_dir (never $root_dir).
cleanup_empty_parent_dirs() {
  local root_dir=$1
  local removed_path=$2
  local parent_dir=""

  parent_dir="$(dirname "$removed_path")"
  while [[ $parent_dir != "$root_dir" && $parent_dir == "$root_dir"/* ]]; do
    if rmdir "$parent_dir" 2> /dev/null; then
      parent_dir="$(dirname "$parent_dir")"
    else
      break
    fi
  done
}

# Prune local branches (and their worktrees) whose refs/remotes/origin/*
# upstream no longer exists, while protecting dirty, locked, current-dir,
# outside-root, local-only, and default-branch worktrees.
prune_orphan_worktrees() {
  local bare_dir=$1
  local worktrees_dir=$2
  local -n pruned_ref=$3
  local -n skipped_ref=$4

  local norm_root=""
  local norm_pwd=""
  local default_upstream=""
  local default_branch=""
  local line=""
  local current_wt=""
  local current_branch=""
  local current_locked=0
  local branch=""
  local upstream_ref=""
  local wt_path=""
  local norm_wt=""
  local wt_status=""

  local -A wt_path_by_branch=()
  local -A wt_locked_by_branch=()

  norm_root="$(realpath -m -- "$worktrees_dir")"
  norm_pwd="$(realpath -m -- "$PWD")"

  default_upstream="$(git --git-dir="$bare_dir" symbolic-ref --quiet refs/remotes/origin/HEAD 2> /dev/null || true)"
  if [[ $default_upstream == refs/remotes/origin/* ]]; then
    default_branch="${default_upstream#refs/remotes/origin/}"
  fi

  # Parse `git worktree list --porcelain` into branch -> path/locked maps.
  while IFS= read -r line; do
    if [[ -z $line ]]; then
      if [[ -n $current_branch && -n $current_wt ]]; then
        wt_path_by_branch["$current_branch"]="$current_wt"
        wt_locked_by_branch["$current_branch"]="$current_locked"
      fi
      current_wt=""
      current_branch=""
      current_locked=0
      continue
    fi

    case "$line" in
      "worktree "*)
        current_wt="${line#worktree }"
        ;;
      "branch refs/heads/"*)
        current_branch="${line#branch refs/heads/}"
        ;;
      "locked" | "locked "*)
        current_locked=1
        ;;
    esac
  done < <(git --git-dir="$bare_dir" worktree list --porcelain 2> /dev/null || true)

  if [[ -n $current_branch && -n $current_wt ]]; then
    wt_path_by_branch["$current_branch"]="$current_wt"
    wt_locked_by_branch["$current_branch"]="$current_locked"
  fi

  # Inspect local branches using locale-independent refs/upstreams.
  while IFS=$'\t' read -r branch upstream_ref; do
    [[ -n $branch ]] || continue
    [[ -n $upstream_ref ]] || continue
    [[ $upstream_ref == refs/remotes/origin/* ]] || continue

    if [[ -n $default_upstream && $upstream_ref == "$default_upstream" ]]; then
      continue
    fi
    if [[ -n $default_branch && $branch == "$default_branch" ]]; then
      continue
    fi

    # Upstream ref still exists on origin: active branch, leave untouched.
    if git --git-dir="$bare_dir" show-ref --verify --quiet "$upstream_ref"; then
      continue
    fi

    if [[ -n ${wt_path_by_branch[$branch]:-} ]]; then
      wt_path="${wt_path_by_branch[$branch]}"
      norm_wt="$(realpath -m -- "$wt_path")"

      if [[ $norm_wt != "$norm_root"/* ]]; then
        print_warn "Skipped orphan ${CYAN}$branch${NC} ${GRAY}(outside worktrees root: $norm_wt)${NC}"
        skipped_ref+=("$branch (outside)")
        continue
      fi

      if ((${wt_locked_by_branch[$branch]:-0} == 1)); then
        print_warn "Skipped orphan ${CYAN}$branch${NC} ${GRAY}(locked)${NC}"
        skipped_ref+=("$branch (locked)")
        continue
      fi

      if [[ $norm_pwd == "$norm_wt" || $norm_pwd == "$norm_wt"/* ]]; then
        print_warn "Skipped orphan ${CYAN}$branch${NC} ${GRAY}(current-dir)${NC}"
        skipped_ref+=("$branch (current-dir)")
        continue
      fi

      if [[ ! -d $norm_wt ]]; then
        git --git-dir="$bare_dir" worktree prune
        git --git-dir="$bare_dir" branch -D "$branch" > /dev/null
        cleanup_empty_parent_dirs "$norm_root" "$norm_wt"
        pruned_ref+=("$branch")
        print_step "Pruned stale worktree & branch: ${CYAN}$branch${NC}"
        continue
      fi

      if ! wt_status="$(git -C "$norm_wt" status --porcelain 2>&1)" || [[ -n $wt_status ]]; then
        print_warn "Skipped orphan ${CYAN}$branch${NC} ${GRAY}(dirty)${NC}"
        skipped_ref+=("$branch (dirty)")
        continue
      fi

      git -C "$worktrees_dir" worktree remove "$norm_wt"
      # Use -D (not -d) on clean [gone] branches so squash-merged branches—whose
      # original tip is not an ancestor of the base branch—are still removed.
      git --git-dir="$bare_dir" branch -D "$branch" > /dev/null
      cleanup_empty_parent_dirs "$norm_root" "$norm_wt"
      pruned_ref+=("$branch")
      print_step "Pruned worktree & branch: ${CYAN}$branch${NC}"
    else
      git --git-dir="$bare_dir" branch -D "$branch" > /dev/null
      pruned_ref+=("$branch")
      print_step "Pruned branch: ${CYAN}$branch${NC} ${GRAY}(no worktree)${NC}"
    fi
  done < <(git --git-dir="$bare_dir" for-each-ref --format='%(refname:short)%09%(upstream)' refs/heads/)

  git --git-dir="$bare_dir" worktree prune

  if ((${#pruned_ref[@]} == 0 && ${#skipped_ref[@]} == 0)); then
    print_info "No orphan worktrees or branches found"
  fi
}
