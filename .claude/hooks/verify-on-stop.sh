#!/bin/bash
#
# Stop hook, fires when the agent tries to end its turn.
#
# The deterministic finish gate. Two questions:
#   1. Is the project green?                    -> `make verify`
#   2. Is the work done, and honestly reported? -> the finish block
#
# (2) used to be missing. The old hook read stdin and discarded it, so the only thing between an
# agent and "done" was the compiler. A test suite with no assertions passes a compiler forever.
#
# ---------------------------------------------------------------------------------------------
# THE FINISH BLOCK IS A FILE, NOT PROSE.
#
# The agent writes .gate/finish-block.md before ending the turn:
#
#   CHANGED:      Sources/DoseModel.swift, Tests/DoseModelTests.swift
#   WHY:          <why this change and not another>
#   VERIFIED:     make verify green · .artifacts/2026-07-30-1432.png
#   NOT VERIFIED: VoiceOver, iPad layout
#   TICKET:       https://github.com/<owner>/<repo>/issues/42   (required when CHANGED is not "nothing")
#   OVERRIDE:     <reason>            (waives the SOFT checks only, never CHANGED, never the build)
#
# WHY A FILE. The first version scraped the agent's final message out of the transcript jsonl.
# That does not work: Claude Code has not flushed the just-emitted assistant text when the Stop
# hook runs, so the hook reads ONE MESSAGE BEHIND. Observed in PackMagic 2026-07-30: a turn that
# did include a finish block was told "no finish block", and the next turn's block was judged
# against the previous turn's text.
#
# A tool call completes before Stop fires, so a file has no race. It also deleted a pile of
# complexity that only existed to compensate for scraping: timestamp scoping, sidechain
# filtering, promptId archaeology. An artefact on disk is checkable; scraped prose is not.
#
# Staleness is handled by file mtime: the block must be NEWER than .claude/.turn-start, so a
# block left over from a previous turn cannot satisfy this one.
#
# WHY .gate/ AND NOT .claude/. Writing anywhere under .claude/ makes Claude Code treat it as a
# settings-adjacent write and offer the user "Yes, and allow Claude to edit its own settings for
# this session". That is a full bypass of every deny rule, offered as a convenience on the single
# most routine action in the workflow. Putting the block in .gate/ keeps the every-turn write
# ordinary, so .claude/** can be denied wholesale without breaking the thing it protects.
# ---------------------------------------------------------------------------------------------
#
# WHAT IS ACTUALLY CHECKED. Three of the four against the filesystem, so none of it relies on
# the agent being honest:
#
#   CHANGED       must list every file that changed THIS TURN. Compared against a hashed
#                 snapshot of the dirty set taken at turn start, so pre-existing uncommitted
#                 work is NOT attributed to this turn. Committed work during the turn counts.
#   NOT VERIFIED  must be present. May say "nothing". Omission stops being free.
#   VERIFIED      must cite a fresh artefact when the diff touched UI.
#   WHY           presence and length only. Not machine-verifiable, and says so rather than
#                 pretending otherwise.
#
# Contract with Claude Code:
#   stdin  = JSON about the stop event (must be consumed or the caller can block on the pipe)
#   exit 0 = allow the turn to end
#   exit 2 = BLOCK, stderr goes back to the agent, it keeps working
#
# Loop safety: Claude Code overrides this hook after 8 consecutive blocks. Every block is
# logged, so eight-blocks-then-exit no longer looks identical to success.
#
# FAILS LOUD (FD-0003). A missing Makefile or an unreadable marker is a BROKEN GATE, not a pass.

set -uo pipefail

DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MARKER="$DIR/.claude/.turn-start"
DIRTY="$DIR/.claude/.turn-dirty"
BLOCKFILE="$DIR/.gate/finish-block.md"
LOG="$DIR/.claude/gate.log"

# Changed files matching this mean "this touched UI, prove it on a device".
# One line, so it is easy to tune per app rather than buried in logic.
# BOOT-62: /Views/ used to match on its own, so any path with a Views directory demanded a simulator
# screenshot. Outside iOS that is an ordinary directory name and there is no device to prove anything
# on, leaving an agent with no legitimate move. A Views/ path must now also be a UI file.
UI_PATTERN='(View\.swift$|/Views/.*\.(swift|xib|storyboard)$|\.xib$|\.storyboard$)'

# BOOT-65: guarded. Sourced under `set -uo pipefail` with no `set -e`, a failed source did not stop
# the script: gate_changed_this_turn became "command not found", ACTUAL and MISSING came out empty,
# the comparison this gate exists for never ran, and the hook exited 0. A turn concealing a change
# passed. FD-0002 says hooks fail closed; this one failed open, and silently.
. "$(dirname "${BASH_SOURCE[0]}")/lib-gate.sh" || {
  echo "STOP BLOCKED by verify-on-stop: lib-gate.sh could not be sourced, so the CHANGED check cannot run." >&2
  echo "The gate is broken, not passing. Reinstall the enforcement layer before ending a turn." >&2
  exit 2
}

stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }
logline() { mkdir -p "$DIR/.claude" 2>/dev/null; echo "$(stamp) $1" >> "$LOG"; }

# THE LOG GETS THE REASON, STDERR GETS THE HELP.
#
# `block` used to write its whole argument to gate.log, and every block message ends with the
# fourteen-line HOWTO. That cost 709 bytes per block against 30 for a pass, storing the same
# help text over and over, and it made gate.log a file whose entries span many lines. Every
# line-based reader then lied: `tail -15` showed three turns, and `grep -c " OVERRIDE"` counted
# the help text's own mentions and reported nine overrides where there were four.
#
# The agent still gets the full text on stderr, which is where it is actually read.
block() {
  logline "BLOCK $(printf '%s' "$1" | head -1)"
  echo "STOP BLOCKED by verify-on-stop: $1" >&2
  exit 2
}

HOWTO='Write .gate/finish-block.md with these lines, then end the turn:

  CHANGED:      <comma-separated paths, or "nothing">
  WHY:          <why this change and not another, at least 20 chars>
  VERIFIED:     <what you actually checked>
  NOT VERIFIED: <what you did not check, or "nothing">
  TICKET:       <full github issue URL; required whenever CHANGED is not "nothing">
  OVERRIDE:     <reason>   (optional; waives WHY-length, VERIFIED/NOT VERIFIED, device check)

CHANGED is ALWAYS required and ALWAYS checked against the diff. A plain OVERRIDE does not waive
it. Waiving it needs OVERRIDE-CHANGED plus a one-shot token only a human can create.'

# stdin must be consumed even though the block now comes from a file.
cat >/dev/null

# ---------------------------------------------------------------- the finish block
[ -f "$MARKER" ] || block "no .claude/.turn-start marker, so 'what changed this turn' is unknowable. Is the UserPromptSubmit hook wired? The gate is broken, not passing."

[ -f "$BLOCKFILE" ] || block "no finish block.

$HOWTO"

# mtime, not content: a block from a previous turn must not satisfy this one. `-newer` is POSIX
# and behaves the same on BSD (macOS) and GNU find.
if [ -z "$(find "$BLOCKFILE" -newer "$MARKER" 2>/dev/null)" ]; then
  block "the finish block is STALE: it predates this turn. Rewrite .gate/finish-block.md for the work you just did.

$HOWTO"
fi

FINAL=$(cat "$BLOCKFILE" 2>/dev/null || echo "")

# EXACTLY ONE BLOCK. A file containing two finish blocks is ambiguous, and the parsers below take
# the FIRST of each field (grep -m1, head -1), so a stale block appended to would silently hand
# authority to a PREVIOUS turn's claim, including its OVERRIDE. Rewriting the file is the contract;
# appending to it is not. Fail loud rather than guess which block was meant.
for _f in CHANGED WHY VERIFIED "NOT VERIFIED" TICKET OVERRIDE OVERRIDE-CHANGED; do
  _n=$(printf '%s\n' "$FINAL" | grep -cE "^[[:space:]]*${_f}:" || true)
  if [ "${_n:-0}" -gt 1 ]; then
    block "the finish block contains ${_n} '${_f}:' lines, so it is ambiguous and the parser would
read the FIRST, which is a previous turn's claim. The file was edited rather than replaced.

Rewrite .gate/finish-block.md completely, with one block for this turn only.

$HOWTO"
  fi
done

# Two different overrides, deliberately unequal in power.
#
#   OVERRIDE:          waives the SOFT checks (WHY length, VERIFIED / NOT VERIFIED presence,
#                      the device artefact). Self-issued by the agent, logged.
#   OVERRIDE-CHANGED:  waives the CHANGED-versus-diff check. Requires a one-shot token that
#                      only a human can create. Consumed on use.
#
# WHY THEY DIFFER. The first version had a single OVERRIDE that waived everything, including
# CHANGED. Since the agent writes that line itself, an agent willing to conceal a change could
# delete a feature, write "CHANGED: nothing", add "OVERRIDE: read-only turn", and pass. The
# override was designed as "the human decides" and was in practice self-serve.
#
# CHANGED is the record of what happened. It must never be waivable by the thing being recorded.
# If there is a legitimate reason not to account for something, declare it AND explain: those
# are not in conflict.
OVERRIDE=$(printf '%s' "$FINAL"        | grep -m1 -E '^[[:space:]]*OVERRIDE:' || true)
OVR_CHANGED=$(printf '%s' "$FINAL"     | grep -m1 -E '^[[:space:]]*OVERRIDE-CHANGED:' || true)
TOKEN="$DIR/.claude/allow-changed-override"

# ---------------------------------------------------------------- soft checks (OVERRIDE waives)
if [ -n "$OVERRIDE" ]; then
  REASON=$(printf '%s' "$OVERRIDE" | sed -E 's/^[[:space:]]*OVERRIDE:[[:space:]]*//')
  logline "OVERRIDE $REASON"
  mkdir -p "$DIR/.claude" 2>/dev/null
  echo "$(stamp) $REASON" >> "$DIR/.claude/override.log"
  echo "verify-on-stop: soft checks waived by OVERRIDE, logged to .claude/override.log." >&2
  echo "CHANGED is still checked against the diff, and make verify still runs." >&2
else
  # BOOT-96: THESE TWO CARRY THE FORMAT, LIKE EVERY OTHER BLOCK IN THIS FILE.
  #
  # They were one sentence each, naming the absent field and nothing else, while every neighbouring
  # block appends $HOWTO. So an agent that wrote NO finish block got better guidance than one that
  # wrote an almost-correct one, and the near miss is the case that most needs the format.
  #
  # Hit for real in PodaKnows on 2026-08-12. A session wrote the block as markdown headings, because
  # the finish-block contract describes the fields in prose and never shows a FIELD: line. The reply
  # was "finish block is missing the 'WHY:' line." The agent could not learn the format from that, so
  # it read this hook's source to find $HOWTO. The gate was right to block; it just did not say what
  # right looks like, which is the whole of FD-0013.
  for field in WHY VERIFIED "NOT VERIFIED"; do
    printf '%s' "$FINAL" | grep -qE "^[[:space:]]*${field}:" \
      || block "finish block is missing the '${field}:' line.

$HOWTO"
  done
  WHY=$(printf '%s' "$FINAL" | sed -nE 's/^[[:space:]]*WHY:[[:space:]]*//p' | head -1)
  [ "${#WHY}" -ge 20 ] \
    || block "WHY is empty or too short (${#WHY} chars). Say why this change and not another.

$HOWTO"
fi

# ---------------------------------------------------------------- CHANGED (never soft-waivable)
printf '%s' "$FINAL" | grep -qE '^[[:space:]]*CHANGED:' || block "finish block has no CHANGED: line. It is required even with an OVERRIDE.

$HOWTO"

[ -f "$DIRTY" ] || block "no .claude/.turn-dirty snapshot, so pre-existing uncommitted work cannot be told apart from this turn's. The gate is broken, not passing."
START_SHA=$(sed -nE 's/^sha=//p' "$MARKER" | head -1)
[ "$START_SHA" != "NO_GIT" ] || block "the turn started outside a git repo, so changes cannot be verified. The gate is broken, not passing."

ACTUAL=$(gate_changed_this_turn "$START_SHA" "$DIRTY")
# "nothing" is the documented way to declare an empty change set. Without dropping it here it is
# parsed as a file literally named "nothing", which logs a false "claimed-but-unchanged: nothing"
# NOTE on every read-only turn. Harmless, but it reads as a positive signal, which is worse than
# noise: an agent reported it back as confirmation the check had passed.
CLAIMED=$(printf '%s' "$FINAL" | sed -nE 's/^[[:space:]]*CHANGED:[[:space:]]*//p' | head -1 \
          | tr ',' '\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | sed '/^$/d' \
          | { grep -viE '^(nothing|none|n/a)$' || true; } | sort -u)

# ---------------------------------------------------------------- TICKET (R1, O3: blocks)
# A turn that changed files cites the ticket it was done under. A read-only turn needs none, which
# keeps the rule off the turns where it buys nothing. OVERRIDE does not waive it: an untracked
# change is exactly what the board exists to prevent. Must be a link, never a bare number, because
# a bare number is unresolvable from a transcript six weeks later.
if [ -n "$CLAIMED" ]; then
  TICKET=$(printf '%s' "$FINAL" | sed -nE 's/^[[:space:]]*TICKET:[[:space:]]*//p' | head -1)
  if [ -z "$TICKET" ]; then
    block "this turn changed files, so the finish block needs a TICKET: line. Every change is tracked on the board (FD-0000, R1).

  TICKET:  https://github.com/<owner>/<repo>/issues/<n>

A read-only turn needs no ticket. If there is no ticket for this work, stop and ask for one; do not invent a number."
  fi
  printf '%s' "$TICKET" | grep -qE 'https://github\.com/[^/]+/[^/]+/issues/[0-9]+' \
    || block "TICKET must be a full GitHub issue URL, not '$TICKET'. A bare number cannot be resolved from a transcript later."
fi

MISSING=$(comm -23 <(printf '%s\n' "$ACTUAL") <(printf '%s\n' "$CLAIMED") | sed '/^$/d')
if [ -n "$MISSING" ]; then
  if [ -n "$OVR_CHANGED" ] && [ -f "$TOKEN" ]; then
    R=$(printf '%s' "$OVR_CHANGED" | sed -E 's/^[[:space:]]*OVERRIDE-CHANGED:[[:space:]]*//')
    logline "OVERRIDE-CHANGED (token consumed) $R | undeclared: $(printf '%s' "$MISSING" | tr '\n' ' ')"
    echo "$(stamp) CHANGED-OVERRIDE $R | undeclared: $(printf '%s' "$MISSING" | tr '\n' ' ')" >> "$DIR/.claude/override.log"
    rm -f "$TOKEN"   # one-shot: each use needs a fresh human action
    echo "verify-on-stop: CHANGED check waived by human token, which has now been consumed." >&2
  elif [ -n "$OVR_CHANGED" ]; then
    block "OVERRIDE-CHANGED requires human authorisation and none is present.

A human must run:  touch .claude/allow-changed-override

The agent cannot create that file: it is denied in settings.json and blocked in guard-bash.sh.
Undeclared changes this turn:
$(printf '%s' "$MISSING" | sed 's/^/    /')"
  else
    block "CHANGED does not match what changed this turn. These changed but were not declared:
$(printf '%s' "$MISSING" | sed 's/^/    /')
Declare them. A plain OVERRIDE does NOT waive this check: CHANGED is the record of what
happened and cannot be waived by the thing being recorded.
(Files already modified before this turn began are NOT counted, only what you changed.)

CHANGED: MUST BE ONE LINE. It is read with 'head -1', so a list wrapped across two lines
declares only what is on the first, and everything after it is invisible to this check. That
is what a file appears here as when it WAS declared. Put the whole comma-separated list on the
CHANGED: line, however long it gets. (BOOT-96)"
  fi
fi

EXTRA=$(comm -13 <(printf '%s\n' "$ACTUAL") <(printf '%s\n' "$CLAIMED") | sed '/^$/d')
[ -n "$EXTRA" ] && logline "NOTE claimed-but-unchanged: $(printf '%s' "$EXTRA" | tr '\n' ' ')"

# ---------------------------------------------------------------- device proof (OVERRIDE waives)
if [ -z "$OVERRIDE" ] && printf '%s\n' "$ACTUAL" | grep -qE "$UI_PATTERN"; then
  # BOOT-75: -size +0c, because any file newer than the marker used to satisfy this and a zero byte
  # file passed. `: > .artifacts/proof.png` was a complete bypass of device proof.
  FRESH=$(find "$DIR/.artifacts" -type f -newer "$MARKER" -size +0c 2>/dev/null | head -1)
  [ -n "$FRESH" ] || block "this turn changed UI files but produced no device artefact.
True in code is not true on device (Rule 2). Capture a simulator screenshot or an accessibility
report into .artifacts/ and cite it in VERIFIED, or add an OVERRIDE: line if a device check
genuinely does not apply."
fi

# ---------------------------------------------------------------- the build gate
# Last, and runs even under OVERRIDE. Cheap checks first, so a missing block costs seconds
# rather than a full build.
command -v make >/dev/null 2>&1 || block "make is not installed, so the finish gate cannot run. Nothing is verified."
[ -f "$DIR/Makefile" ] || block "no Makefile in $DIR, so 'make verify' cannot run. Nothing is verified."

OUT=$(cd "$DIR" && make verify 2>&1)
CODE=$?

if [ "$CODE" -ne 0 ]; then
  logline "BLOCK make verify RED (exit $CODE)"
  echo "make verify is RED (exit $CODE). The turn cannot end until it is green." >&2
  echo "" >&2
  echo "$OUT" >&2
  exit 2
fi

# ---------------------------------------------------------------- record the verified state
# The turn passed, so this is the last state anyone accounted for. turn-start.sh compares against
# it next time and reports anything that drifted in between: a hand edit, another tool, or a turn
# that hit the 8-block override and exited leaving undeclared work behind. That last one is the
# dangerous case, because it looks exactly like a clean finish.
PASS_SHA=$(git -C "$DIR" rev-parse HEAD 2>/dev/null || echo NO_GIT)
{
  echo "sha=$PASS_SHA"
  echo "at=$(stamp)"
  echo "fingerprint=$(gate_fingerprint)"
} > "$DIR/.claude/.last-seen"
# Dirty snapshot of the passing state, so the next turn's drift check has a real baseline
# rather than reusing the previous turn's START snapshot.
gate_dirty_snapshot > "$DIR/.claude/.last-dirty"

# ---------------------------------------------------------------- re-baseline the turn marker
# _ticketflow#28. turn-start.sh is wired to UserPromptSubmit alone. A `!` bash input is not a
# prompt submission, so on those turns it never runs, and the marker still points at wherever some
# EARLIER turn began. This hook does run, diffs against that stale sha, and blames the current turn
# for the previous turn's commits. Under FD-0014 a human `!` push is the normal end of every piece
# of work, so it fires on the most common turn shape there is.
#
# Observed three times on 2026-08-15 in _ticketflow, and it did the damage the ticket predicted:
# the only route past a wrong block is an untrue CHANGED, and CHANGED is the one check that must
# never be waivable by the thing being recorded. Two false records came out of it in one session.
#
# RE-BASELINING HERE rather than wiring a second event is what closes it. A pass is the moment the
# state is known to be accounted for, whatever event began the turn, so it is the honest baseline
# for whatever comes next. There is no event to wire for a `!` input in any case.
#
# This introduces no new failure. A turn that dies before reaching this line leaves the marker
# stale exactly as it does today, and unattributed drift is still caught independently by the
# .last-seen fingerprint written above, which this does not touch.
#
# It also tightens two checks that a stale marker was quietly loosening: a finish block left by an
# earlier turn is now correctly older than the marker and rejected, and a device artefact from an
# earlier turn can no longer satisfy this turn's `-newer "$MARKER"` proof.
{
  echo "sha=$PASS_SHA"
  echo "epoch=$(date +%s)"
  echo "at=$(stamp)"
} > "$MARKER"
# Same snapshot, not a second call: these two must describe one instant. Taking the dirty set twice
# would let a file change between them, and the gate would then read a baseline that never existed.
cp "$DIR/.claude/.last-dirty" "$DIRTY" 2>/dev/null

# CONSUME THE BLOCK. A passing turn deletes it, so the next turn starts with no file at all.
#
# Why: observed in PackMagic 2026-07-30. The agent's Write failed ("Error writing file"), it read
# the existing block, then produced a PARTIAL EDIT that replaced the newest fields and left the
# previous turn's WHY and VERIFIED above them. The gate passed a block whose stated reason was the
# previous turn's answer to a different question.
#
# Validating harder only catches the next variant. Deleting the file removes the class: nothing to
# merge with, no read-before-write to fail, and the staleness check stops being load-bearing.
# Same one-shot logic as the override token.
#
# On a BLOCK the file is deliberately left in place, because the agent needs to see and fix it.
rm -f "$BLOCKFILE" 2>/dev/null

logline "PASS"
exit 0
