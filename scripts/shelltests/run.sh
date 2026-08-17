#!/usr/bin/env bash
# Run every *.test.sh in this directory. No network, no token, no board, no simulator.
#
# THEY LIVE IN scripts/, NOT IN tests/, AND THAT IS DELIBERATE. On a case-insensitive
# filesystem `tests/` and `Tests/` are the SAME DIRECTORY (verified: both report inode
# 70692455 under `stat -f '%i'`), and `Tests/` is the XcodeGen source path for the Swift unit
# test target at project.yml:59-63. A .sh file dropped in there is picked up and copied into
# the .xctest bundle as a resource, in every app generated from this template. Measured with
# `xcodegen generate`: it lands as `probe.test.sh in Resources`.
#
# These are SHELL tests, not Swift tests. They exist to prove one thing: that THIS repo's copy of the
# enforcement layer actually fires. The Swift suite next to them tests the app; nothing tested the
# guard, in any of the ten repos, until _bootstrap#152 defect 4.
#
# THE SCOPE IS DELIBERATELY SMALL. This is not the factory suite. _bootstrap owns the guard and tests
# it in depth there, against every rule it has. Re-testing that here would be ten copies of one
# suite, nine of which nobody would fix when it went red. What an app repo needs to know is narrower
# and it is the thing that actually went wrong: MY guard is installed, MY guard blocks, and MY guard
# does not refuse ordinary work. A guard that was vendored broken, or half-installed, or overwritten
# by a merge, is invisible to every other check in this repo.
#
# The runner enforces three things a plain `for f in *.test.sh` would not:
#   1. There must be at least one test file. An empty suite exiting 0 is the loudest possible way to
#      lie, and it is one `rm` away at all times.
#   2. Every file must PRINT a report line. `lib.sh`'s `report` refuses a file that asserted zero
#      times, but a file that exits early never reaches `report`, so the runner checks the line
#      arrived rather than trusting the exit code.
#   3. Failure is reported per file and then aggregated, so one broken file does not hide the rest.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

files=$(find "$HERE" -maxdepth 1 -name '*.test.sh' | sort)
[ -n "$files" ] || { echo "  no *.test.sh in $HERE, which is not a pass"; exit 1; }

# A scratch file rather than a pipe into grep -q: piping is the pipefail trap lib.sh describes.
SCRATCH=$(mktemp "${TMPDIR:-/tmp}/shelltests.XXXXXX")
trap 'rm -f "$SCRATCH"' EXIT

fail=0
total=0
for f in $files; do
  echo "  $(basename "$f")"
  out=$(bash "$f" 2>&1); rc=$?
  printf '%s\n' "$out" | sed 's/^/  /'
  printf '%s' "$out" > "$SCRATCH"
  if ! grep -qE '[0-9]+ assertions, [0-9]+ failed' "$SCRATCH"; then
    echo "    FAIL  this file never reported, so it did not finish. Treating as broken, not as a pass."
    fail=1
    continue
  fi
  # LAST match, and it must parse as one integer. A file emitting two report-shaped lines used to
  # make the arithmetic error out silently and print a zero total over a green run.
  n=$(grep -oE '[0-9]+ assertions' "$SCRATCH" | grep -oE '[0-9]+' | tail -1)
  case "$n" in
    ''|*[!0-9]*)
      echo "    FAIL  this file's assertion count did not parse as one number. Treating as broken."
      fail=1; continue ;;
  esac
  total=$((total + n))
  [ "$rc" = 0 ] || fail=1
done

nfiles=$(printf '%s\n' "$files" | grep -c .)
echo "  $total assertions across $nfiles shell test file(s)"

# THE FLOOR. A count that only ever goes up is the cheapest defence against a suite that shrank, and
# this factory already uses the shape for iOS coverage (FD-0008). Two independent audits made the
# factory runner print green while running almost nothing: a file truncated to 3 of its 74
# assertions, eleven of twelve files deleted, and a file that asserted nothing and echoed a
# report-shaped line. All three passed.
#
# Raise both numbers when the suite grows. NEVER lower one to make a run pass: a suite that got
# smaller is the thing this is here to notice. If assertions were removed on purpose, lower it in the
# same commit and say why.
FLOOR_FILES=1
FLOOR_ASSERTS=19
if [ "$nfiles" -lt "$FLOOR_FILES" ]; then
  echo "  shell tests: RED. $nfiles files, floor is $FLOOR_FILES. A file went missing, which is not a pass."
  exit 1
fi
if [ "$total" -lt "$FLOOR_ASSERTS" ]; then
  echo "  shell tests: RED. $total assertions, floor is $FLOOR_ASSERTS. The suite got smaller, which is not a pass."
  exit 1
fi

[ "$fail" = 0 ] || { echo "  shell tests: RED"; exit 1; }
echo "  shell tests: green"
