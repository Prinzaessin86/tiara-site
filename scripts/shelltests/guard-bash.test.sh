#!/usr/bin/env bash
# THIS REPO'S OWN guard-bash.sh fires.
#
# WHY THIS FILE EXISTS (_bootstrap#152 defect 4)
#
# guard-bash.sh is the security boundary of every repo in this factory and it is vendored into
# thirteen of them. Until now it was tested in exactly one place, _bootstrap, and the other twelve
# ran a copy that nothing anywhere executed. A vendored file can arrive truncated, arrive with the
# wrong permissions, lose its wiring in .claude/settings.json, or be flattened by a merge, and every
# other check in this repo would stay green through all four. `make conform` compares checksums,
# which catches a changed file and says nothing at all about a file that no longer works.
#
# WHAT THIS DELIBERATELY DOES NOT DO. It does not re-test the factory. _bootstrap owns the guard and
# asserts every rule in it, with the reason named, in tests/guard-bash.test.sh there. Copying that
# here would be ten copies of one suite, nine of which nobody would fix. This file asks three
# narrower questions, and they are the three that have actually gone wrong:
#
#   1. Is the guard here at all, and does it run?
#   2. Does it fail CLOSED when it cannot understand its input?
#   3. Does it block the things it must, and STILL ALLOW ordinary work?
#
# Question 3's second half is not padding. The failure that really happened, for eleven days across
# five repos, was a guard that refused the board commands CLAUDE.md tells an agent to run. A guard
# that blocks everything is not secure, it is broken, and it is the more likely of the two failures
# because every widening of a rule risks it.
#
# Every blocking assertion names the reason it expects. `blocks` alone asks whether SOMETHING
# refused; the guard has forty rules and most interesting commands trip more than one, so an
# assertion written to defend rule X keeps passing after X is deleted.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$HERE/lib.sh"

# Overridable so this file can be pointed at a COPY, which is the only way to watch it fail: hooks
# are gate files and must never be edited to test them.
GUARD="${GUARD_BASH_UNDER_TEST:-$ROOT/.claude/hooks/guard-bash.sh}"

assert "this repo has an installed guard-bash.sh" test -f "$GUARD"
assert "and it is executable"                     test -x "$GUARD"

# A fixture repo, not this one. The push rule reads the CURRENT BRANCH, so running it against the
# working tree would pass or fail depending on what a human happened to check out, which is an
# assertion that silently stops existing. Pin the branch and give it a commit.
TMP=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/guardtest.XXXXXX")" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/proj/scripts"
git -C "$TMP/proj" init -q -b main 2>/dev/null \
  || { git -C "$TMP/proj" init -q; git -C "$TMP/proj" checkout -q -b main; }
git -C "$TMP/proj" config user.email t@t.t
git -C "$TMP/proj" config user.name t
printf 'verify:\n\t@true\n' > "$TMP/proj/Makefile"
git -C "$TMP/proj" add -A >/dev/null 2>&1
git -C "$TMP/proj" commit -q -m init >/dev/null 2>&1
# The fixture asserts itself. If the checkout silently failed this would not be a main repo and the
# push assertion below would pass for the wrong reason.
assert "the fixture repo really is on main" \
  sh -c '[ "$(git -C "$1" rev-parse --abbrev-ref HEAD)" = "main" ]' _ "$TMP/proj"

# Exit 2 is the hook's block. 0 is allow. Anything else is the hook ERRORING, which must never be
# read as either: a guard that crashes is not a guard that permitted the command. So `blocks` tests
# for 2 exactly, never for "not zero".
#
# The payload is built with python3 rather than typed, because a JSON string containing these
# commands has to survive quoting intact; a printf-built payload that breaks on a quote turns a write
# that was never attempted into a write that looks blocked.
judge() {
  printf '{"tool_input":{"command":%s}}' \
    "$(printf '%s' "$1" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')" \
    | ( cd "$TMP/proj" && CLAUDE_PROJECT_DIR="$TMP/proj" bash "$GUARD" >/dev/null 2>&1 )
  printf '%s' "$?"
}
why() {
  printf '{"tool_input":{"command":%s}}' \
    "$(printf '%s' "$1" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')" \
    | ( cd "$TMP/proj" && CLAUDE_PROJECT_DIR="$TMP/proj" bash "$GUARD" 2>&1 >/dev/null )
}
allows() { [ "$(judge "$1")" = 0 ]; }
# blocks_because <command> <substring of the deny reason>. No pipe into grep: this file sets pipefail.
blocks_because() {
  [ "$(judge "$1")" = 2 ] || return 1
  case "$(why "$1")" in *"$2"*) return 0 ;; esac
  return 1
}

echo "  the guard must fail CLOSED, not open"
# A guard that permits when it cannot understand its input is worse than no guard, because it is
# trusted. These go through the hook directly rather than through judge(), since the whole point is
# input the parser cannot use.
assert "empty input is a block" \
  test "$(printf '' | ( cd "$TMP/proj" && bash "$GUARD" >/dev/null 2>&1 ); printf '%s' $?)" = 2
assert "unparseable input is a block" \
  test "$(printf 'not json' | ( cd "$TMP/proj" && bash "$GUARD" >/dev/null 2>&1 ); printf '%s' $?)" = 2
assert "input carrying no command is a block" \
  test "$(printf '{"tool_input":{}}' | ( cd "$TMP/proj" && bash "$GUARD" >/dev/null 2>&1 ); printf '%s' $?)" = 2

echo "  irreversible destruction must be BLOCKED"
assert "recursive delete of home"   blocks_because 'rm -rf ~' 'recursive delete of home'
assert "recursive delete from root" blocks_because 'rm -rf /' 'recursive delete from root'
assert "hard reset"                 blocks_because 'git reset --hard origin/main' 'hard reset'

echo "  an agent does not push to main (FD-0014)"
assert "a push to main is refused, and the reason is the rule" \
  blocks_because 'git push origin main' 'an agent does not push to main'

echo "  the always-loaded documents are not writable from the shell"
assert "a redirect into CLAUDE.md" blocks_because 'echo hi > CLAUDE.md' 'CLAUDE.md'
assert "sed -i on CLAUDE.md"       blocks_because "sed -i '' 's/a/b/' CLAUDE.md" 'CLAUDE.md'

echo "  the board's own doors must be BLOCKED when reached around"
assert "gh issue close, because closing is Done" \
  blocks_because 'gh issue close 3' 'closing a ticket is Done'

echo "  ...and ordinary work must still be ALLOWED, which is the half that broke"
# Not padding. A guard that refuses ordinary work teaches an agent to route around it, and the
# outage this whole layer was repaired after was of exactly this kind: correct blocking, and the
# documented board commands refused for eleven days in five repos.
assert "reading a file"          allows 'cat README.md'
assert "a normal git commit"     allows 'git commit -m "a message"'
assert "a plain git status"      allows 'git status --short'
assert "running these tests"     allows 'bash scripts/shelltests/run.sh'
assert "the documented move-to-verify call" \
  allows 'bash ~/Developer/_ticketflow/scripts/move-to-verify.sh SomeRepo 1 2'
assert "the documented make-board-ticket call" \
  allows 'bash ~/Developer/_ticketflow/scripts/make-board-ticket.sh SomeRepo Chore t /tmp/b.md'

report
