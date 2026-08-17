#!/usr/bin/env bash
# Assertions, and the counting that makes a hollow test file fail.
#
# Vendored from _bootstrap/tests/lib.sh. Keep the two in step; the factory suite is the original.
#
# The counting is the point, not a nicety. A suite that runs green while asserting nothing is worse
# than no suite, because it is credited. On 2026-08-10 four separate checks in the factory passed or
# failed for the wrong reason and THREE OF THE FOUR REPORTED A PASS.
#
# So: every test file must call `report`, `report` refuses a file that asserted zero times, and
# run.sh refuses a file that did not call `report` at all. Those three together mean a file cannot be
# silently empty, silently skipped, or silently exited early.

ASSERTS=0
FAILS=0

# assert <description> <command...>   passes when the command exits 0
assert() {
  desc="$1"; shift
  ASSERTS=$((ASSERTS + 1))
  if "$@" >/dev/null 2>&1; then return 0; fi
  FAILS=$((FAILS + 1))
  printf '    FAIL  %s\n' "$desc"
}

# refute <description> <command...>   passes when the command exits non-zero
refute() {
  desc="$1"; shift
  ASSERTS=$((ASSERTS + 1))
  if "$@" >/dev/null 2>&1; then
    FAILS=$((FAILS + 1))
    printf '    FAIL  %s\n' "$desc"
  fi
}

# assert_eq <description> <expected> <actual>
assert_eq() {
  ASSERTS=$((ASSERTS + 1))
  if [ "$2" = "$3" ]; then return 0; fi
  FAILS=$((FAILS + 1))
  printf '    FAIL  %s\n          expected [%s]\n          actual   [%s]\n' "$1" "$2" "$3"
}

# assert_output_contains <description> <needle> <command...>
#
# WHY THIS EXISTS RATHER THAN `cmd | grep -q`. That idiom is booby-trapped under `set -o pipefail`,
# which every test file here sets. `grep -q` exits the instant it matches, the pipe closes, the
# producer dies of SIGPIPE, and pipefail reports the whole pipeline as FAILED. A test asserting "the
# output contains X" then reports a failure when X is present, and the result depends on where in
# the stream the match falls. It bit three files in one day. Never pipe into grep -q.
#
# The needle is a fixed string, not a pattern.
assert_output_contains() {
  desc="$1"; needle="$2"; shift 2
  ASSERTS=$((ASSERTS + 1))
  out=$("$@" 2>&1)
  case "$out" in
    *"$needle"*) return 0 ;;
  esac
  FAILS=$((FAILS + 1))
  printf '    FAIL  %s\n          output did not contain [%s]\n' "$desc" "$needle"
}

report() {
  if [ "$ASSERTS" -eq 0 ]; then
    printf '    FAIL  this file asserted nothing, which is not a pass\n'
    exit 1
  fi
  printf '    %d assertions, %d failed\n' "$ASSERTS" "$FAILS"
  [ "$FAILS" -eq 0 ]
}
