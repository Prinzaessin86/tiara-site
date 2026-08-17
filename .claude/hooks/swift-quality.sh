#!/bin/bash
#
# PostToolUse hook, fires after the agent writes or edits any file.
#
# This is the teaching loop. It formats what it can fix, and reports what it cannot
# straight back into the agent's context. The agent then corrects itself without you
# having to notice, read, or care.
#
# Contract with Claude Code:
#   exit 0 = silent, the agent is told nothing
#   exit 2 = the agent RECEIVES stderr and reacts to it
#
# Exit 2 is the entire point. Exit 0 sends the report nowhere.
#
# Like guard-bash, this FAILS LOUD. If its tooling is missing it complains instead of
# quietly passing everything, because a quality gate you wrongly trust is worse than
# no quality gate at all.
#
# The same rule applies when a tool is present but ERRORS. A hook must fail loud on
# tool error, never swallow it. If the tool cannot run, that is not a pass, it is a
# gate that is not functioning, and it must exit 2 with the error shown. A gate that
# swallows its tool's failure is worse than no gate: it reports success while checking
# nothing. For SwiftLint specifically: exit 0 (clean) and exit 2 (violations) are the
# only healthy outcomes; any other exit code means the invocation itself failed, so we
# surface it and exit 2.
#
# Concrete history: SwiftLint 0.65 removed the `--path` flag. The old line
#   LINT=$(swiftlint lint --quiet --path "$FILE" 2>/dev/null)
# errored with exit 64, the `2>/dev/null` ate the message, stdout came back empty, and
# the hook passed every file silently while linting nothing. See the ADR
# "quality hooks must fail loud on tool error" in docs/decisions/.

set -uo pipefail

# BOOT-67: the em dash was written as $'\u2014'. `\u` escapes inside $'...' arrived in bash 4.2 and
# macOS ships bash 3.2.57, so the escape was never recognised and this searched every file for the
# six literal characters backslash u 2 0 1 4. The rule had therefore never fired, anywhere, once.
# Built from its UTF-8 bytes instead, which every bash understands.
EM_DASH=$(printf '\xe2\x80\x94')
emdash_check() {
  # -I so a binary file is not scanned and cannot produce an unreadable report.
  if grep -qI "$EM_DASH" "$FILE" 2>/dev/null; then
    REPORT="${REPORT}
HOUSE RULE: em dash found. Em dashes are banned everywhere in this project: code, comments, and user facing copy. Use a comma, a colon, or a full stop."
  fi
}
quality_exit() {
  if [ -n "$REPORT" ]; then
    echo "Quality gate on ${FILE}:${REPORT}" >&2
    echo "" >&2
    echo "Fix these before continuing. Do not move to the next file." >&2
    exit 2
  fi
  exit 0
}

INPUT=$(cat)

parse_path() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c \
      'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null
  else
    echo "__NOPARSER__"
  fi
}

FILE=$(parse_path)

if [ "$FILE" = "__NOPARSER__" ]; then
  echo "QUALITY GATE IS NOT RUNNING: no jq or python3 on PATH. Run: brew install jq" >&2
  echo "Do not treat any result as verified until this is fixed." >&2
  exit 2
fi

# BOOT-61: the house rules below say they apply "everywhere in this project: code, comments, and
# user facing copy", and this returned 0 for anything that was not .swift. So they ran on Swift
# only, which in a repo containing no Swift means they never ran at all. Four repos are in that
# state. The Swift-only tooling (swiftformat, swiftlint) still runs on Swift only.
IS_SWIFT=0
case "$FILE" in
  *.swift) IS_SWIFT=1 ;;
  *.md|*.markdown|*.sh|*.bash|*.zsh|*.yml|*.yaml|*.json|*.txt|*.psv|*.tsv) ;;
  *) exit 0 ;;
esac

[ -f "$FILE" ] || exit 0

REPORT=""

# A missing swiftlint must still be loud (FD-0003), but it is not a reason to refuse a markdown
# edit. A non-Swift file takes the house rules and nothing else.
if [ "$IS_SWIFT" = 0 ]; then
  emdash_check
  quality_exit
fi

# --- The tools must exist. If they do not, say so. Do not pass silently. -----
MISSING=""
command -v swiftformat >/dev/null 2>&1 || MISSING="${MISSING} swiftformat"
command -v swiftlint   >/dev/null 2>&1 || MISSING="${MISSING} swiftlint"
if [ -n "$MISSING" ]; then
  echo "QUALITY GATE IS NOT RUNNING. Missing tools:${MISSING}" >&2
  echo "Run: brew install${MISSING}" >&2
  echo "Until then, nothing in this project has been linted. Do not report anything as done." >&2
  exit 2
fi

# --- 1. Fix what can be fixed automatically ----------------------------------
# BOOT-68: the exit code is read and stderr is kept. This line used to be
# `swiftformat "$FILE" --quiet 2>/dev/null`, which is the exact pattern this file's own header
# describes as the bug it was written to remove: SwiftLint 0.65 dropped --path, the old call errored
# with exit 64, 2>/dev/null ate the message, and the hook passed every file while linting nothing.
# The fix was applied to the lint call and not to the format call beside it.
FMT_OUT=$(swiftformat "$FILE" --quiet 2>&1)
FMT_CODE=$?
if [ "$FMT_CODE" -ne 0 ]; then
  echo "swift-quality: swiftformat could not run on $FILE (exit $FMT_CODE)." >&2
  echo "$FMT_OUT" >&2
  echo "the format gate is not functioning. fix the invocation before trusting it." >&2
  exit 2
fi

# --- 2. Report what cannot ----------------------------------------------------
# _bootstrap#144: violations arrive on STDOUT as JSON. SwiftLint's own diagnostics arrive on
# STDERR, including a config note about an opt-in analyzer rule that has nothing to do with the
# file being edited. The old call merged the two with 2>&1 and blocked on any output at all, so a
# byte-clean file was refused in every repo whose .swiftlint.yml opts into such a rule: measured as
# 7 of 8 Swift repos. Read the violations, not the noise. Keep stderr for the tool-error branch,
# which is the FD-0003 guarantee and must not be weakened.
LINT_ERRFILE=$(mktemp "${TMPDIR:-/tmp}/swiftlint.XXXXXX")
LINT_OUT=$(swiftlint lint --quiet --reporter json "$FILE" 2>"$LINT_ERRFILE")
LINT_CODE=$?
LINT_ERR=$(cat "$LINT_ERRFILE"); rm -f "$LINT_ERRFILE"

# Tool level failure. Never pass silently. This is the guard the old hook was missing.
if [ "$LINT_CODE" -ne 0 ] && [ "$LINT_CODE" -ne 2 ]; then
    echo "swift-quality: swiftlint could not run on $FILE (exit $LINT_CODE)." >&2
    echo "$LINT_ERR" >&2
    echo "the lint gate is not functioning. fix the invocation before trusting it." >&2
    exit 2
fi

# A reporter whose output cannot be parsed is a broken gate, not a clean file. Fail loud.
LINT_REPORT=$(printf '%s' "$LINT_OUT" | python3 -c '
import sys, json
try:
    v = json.load(sys.stdin)
except Exception:
    sys.exit(3)
out = []
for e in v:
    sev = str(e.get("severity", "")).lower()
    if sev not in ("error", "warning"):
        continue
    out.append("  %s:%s:%s %s: %s" % (e.get("file", ""), e.get("line", ""),
                                      e.get("character", ""), sev, e.get("reason", "")))
print("\n".join(out))
' 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "swift-quality: could not parse SwiftLint JSON for $FILE." >&2
    echo "$LINT_OUT" >&2
    echo "the lint gate is not functioning. fix the invocation before trusting it." >&2
    exit 2
fi

# Real violations block so the agent self corrects. A config note on stderr does not.
if [ -n "$LINT_REPORT" ]; then
    echo "swift-quality: SwiftLint reported violations in $FILE:" >&2
    echo "$LINT_REPORT" >&2
    exit 2
fi

# --- 3. House rules a linter cannot express -----------------------------------
# Grow this list every time the agent gets something wrong twice.
# A rule here is cheaper forever than the same correction in chat every sprint.

emdash_check

# --- Per app house rules go here ---------------------------------------------
# Add a grep block for anything THIS app must never contain. Write an ADR for the
# rule first, then enforce it here so it can never quietly regress. Example: an app
# that must never shame the user would enforce it like this (uncomment and adapt):
#
#   FORBIDDEN=$(grep -niE 'streak|overdue|missed|failed|guilt' "$FILE" 2>/dev/null || true)
#   if [ -n "$FORBIDDEN" ]; then
#     REPORT="${REPORT}
#   HOUSE RULE (see docs/decisions/): forbidden vocabulary found. Review these lines:
#   ${FORBIDDEN}"
#   fi

if [ -n "$REPORT" ]; then
  echo "Quality gate on ${FILE}:${REPORT}" >&2
  echo "" >&2
  echo "Fix these before continuing. Do not move to the next file." >&2
  exit 2
fi

exit 0
