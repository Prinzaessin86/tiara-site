#!/bin/bash
# Can the hooks actually RUN? Not: do the files exist, and not: do they hash correctly.
#
# WHY THIS EXISTS. On 2026-08-17 a single `chmod -x .claude/hooks/*.sh` disarmed all six hooks in a
# real repo. Measured consequences, each by execution:
#
#   git hash-object      IDENTICAL before and after. A mode change is not content, so every
#                        content hash in this factory is structurally blind to it.
#   make manifest        "enforcement layer matches its manifest", exit 0.
#   the harness          PreToolUse:Bash, PreToolUse:Write, PostToolUse:Write and Stop each reported
#                        "Failed with non-blocking status code ... Permission denied", and every
#                        action proceeded. Four of the five wired events failed open at once.
#
# So nothing in the estate could tell an armed layer from a disarmed one. That is what this checks.
#
# THE TRAP THIS SCRIPT EXISTS TO AVOID, and the reason it is not a one-liner. A probe written as
# `bash "$hook"` reports HEALTHY on a disarmed layer, because bash will happily interpret a file
# with no execute bit. Measured: `bash h.sh` returns 2 while `./h.sh` returns 126. The harness uses
# the second form. So this script invokes the hook DIRECTLY and never through an interpreter, and it
# tests the execute bit explicitly rather than inferring it from a successful run.
# scripts/compliance.mjs had exactly this flaw at runGuard.
#
# Exit 0 = every hook can run and the guard still refuses. Exit 1 = the layer is not enforcing.
set -uo pipefail

DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HOOKDIR="$DIR/.claude/hooks"
HOOKS="lib-gate.sh turn-start.sh verify-on-stop.sh guard-bash.sh guard-scope.sh swift-quality.sh"

fail=0

if [ ! -d "$HOOKDIR" ]; then
  echo "  no .claude/hooks in $DIR, so there is no layer to check"
  exit 1
fi

for h in $HOOKS; do
  p="$HOOKDIR/$h"
  if [ ! -f "$p" ]; then
    echo "  MISSING        $h"
    fail=1
  elif [ ! -x "$p" ]; then
    echo "  NOT EXECUTABLE $h  (mode $(stat -f '%Lp' "$p" 2>/dev/null || stat -c '%a' "$p"))"
    echo "                 the harness cannot run it. It reports a non-blocking error and proceeds."
    fail=1
  else
    echo "  ok             $h"
  fi
done

# Behavioural check. The execute bit says the file COULD run; this says it still refuses what it is
# meant to refuse. Invoked directly, exactly as the harness does, never via `bash`.
if [ -x "$HOOKDIR/guard-bash.sh" ]; then
  printf '{"tool_input":{"command":"rm -rf /"}}' | "$HOOKDIR/guard-bash.sh" >/dev/null 2>&1
  rc=$?
  if [ "$rc" = 2 ]; then
    echo "  ok             guard-bash refuses a blocked command (exit 2)"
  else
    echo "  NOT ENFORCING  guard-bash returned $rc on a command it must refuse, expected 2"
    fail=1
  fi
fi

if [ "$fail" = 0 ]; then
  echo "  the enforcement layer can run and is refusing"
else
  echo ""
  echo "  Restore with: chmod +x .claude/hooks/*.sh"
  echo "  Then re-run this check. If a hook is missing rather than unexecutable, re-install the"
  echo "  layer: bash ~/Developer/_bootstrap/scripts/install-enforcement.sh <this repo>"
fi
exit $fail
