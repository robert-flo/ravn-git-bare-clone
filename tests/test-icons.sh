#!/usr/bin/env bash
# Test that ICON_* in global_fn.sh emit real UTF-8 emojis even without a TTY,
# keep ANSI colors disabled without a TTY, and fall back to ASCII under
# NO_COLOR or TERM=dumb.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly GLOBAL_FN="$REPO_ROOT/runtime/lib/global_fn.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

eval_icons() {
  local term_val="$1"
  local no_color_val="$2"
  # shellcheck disable=SC2016
  env TERM="$term_val" NO_COLOR="$no_color_val" bash -c '
    source "$1"
    printf "RED=[%s]\n" "$RED"
    printf "CHECK=%s\n" "$ICON_CHECK"
    printf "CROSS=%s\n" "$ICON_CROSS"
    printf "ARROW=%s\n" "$ICON_ARROW"
    printf "WARN=%s\n" "$ICON_WARN"
    printf "INFO=%s\n" "$ICON_INFO"
    printf "KEY=%s\n" "$ICON_KEY"
    printf "LOCK=%s\n" "$ICON_LOCK"
    printf "GIT=%s\n" "$ICON_GIT"
    printf "GITHUB=%s\n" "$ICON_GITHUB"
    printf "GEAR=%s\n" "$ICON_GEAR"
    printf "ROCKET=%s\n" "$ICON_ROCKET"
    printf "PACKAGE=%s\n" "$ICON_PACKAGE"
    printf "FOLDER=%s\n" "$ICON_FOLDER"
    printf "BRANCH=%s\n" "$ICON_BRANCH"
    printf "CLONE=%s\n" "$ICON_CLONE"
    printf "PUSH=%s\n" "$ICON_PUSH"
    printf "ISSUE=%s\n" "$ICON_ISSUE"
  ' _ "$GLOBAL_FN"
}

# 1. Without a TTY (command substitution / pipe), ANSI colors are empty and
#    ICON_* use real UTF-8 emojis (never ASCII fallbacks or Nerd Font PUA).
non_tty_out="$(eval_icons "xterm-256color" "")"

[[ "$non_tty_out" == *"RED=[]"* ]] || fail "expected ANSI RED to be empty without TTY: $non_tty_out"
[[ "$non_tty_out" == *"ROCKET=🚀"* ]] || fail "expected real rocket emoji without TTY: $non_tty_out"
[[ "$non_tty_out" == *"GEAR=⚙️"* ]] || fail "expected real gear emoji without TTY: $non_tty_out"
[[ "$non_tty_out" == *"PACKAGE=📦"* ]] || fail "expected real package emoji without TTY: $non_tty_out"
[[ "$non_tty_out" == *"KEY=🔑"* ]] || fail "expected real key emoji without TTY: $non_tty_out"
[[ "$non_tty_out" == *"LOCK=🔒"* ]] || fail "expected real lock emoji without TTY: $non_tty_out"
[[ "$non_tty_out" == *"FOLDER=📁"* ]] || fail "expected real folder emoji without TTY: $non_tty_out"
[[ "$non_tty_out" != *"[ROCKET]"* ]] || fail "did not expect ASCII [ROCKET] without NO_COLOR/TERM=dumb: $non_tty_out"
[[ "$non_tty_out" != *"[GEAR]"* ]] || fail "did not expect ASCII [GEAR] without NO_COLOR/TERM=dumb: $non_tty_out"

# 2. With NO_COLOR=1, both ANSI colors and icons fall back to ASCII.
no_color_out="$(eval_icons "xterm-256color" "1")"

[[ "$no_color_out" == *"CHECK=[OK]"* ]] || fail "expected [OK] when NO_COLOR=1: $no_color_out"
[[ "$no_color_out" == *"ROCKET=[ROCKET]"* ]] || fail "expected [ROCKET] when NO_COLOR=1: $no_color_out"
[[ "$no_color_out" == *"GEAR=[GEAR]"* ]] || fail "expected [GEAR] when NO_COLOR=1: $no_color_out"
[[ "$no_color_out" == *"FOLDER=[FOLDER]"* ]] || fail "expected [FOLDER] when NO_COLOR=1: $no_color_out"

# 3. With TERM=dumb, both ANSI colors and icons fall back to ASCII.
dumb_out="$(eval_icons "dumb" "")"

[[ "$dumb_out" == *"CHECK=[OK]"* ]] || fail "expected [OK] when TERM=dumb: $dumb_out"
[[ "$dumb_out" == *"ROCKET=[ROCKET]"* ]] || fail "expected [ROCKET] when TERM=dumb: $dumb_out"
[[ "$dumb_out" == *"GEAR=[GEAR]"* ]] || fail "expected [GEAR] when TERM=dumb: $dumb_out"
[[ "$dumb_out" == *"PACKAGE=[PACKAGE]"* ]] || fail "expected [PACKAGE] when TERM=dumb: $dumb_out"

printf 'global_fn.sh UTF-8 icons contract: passed\n'
