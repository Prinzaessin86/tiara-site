#!/bin/bash
#
# UserPromptSubmit hook, fires when you send a message, i.e. at the START of a turn.
#
# Three jobs:
#
# 0. CLEAR ANY SURVIVING FINISH BLOCK, so every turn starts from nothing. See below for why
#    consume-on-pass in the Stop hook was not enough on its own.
#
# 1. RECORD WHERE THIS TURN BEGAN, so the Stop hook can ask "what changed this turn?" and
#    get a truthful answer. `git diff --name-only` shows only UNCOMMITTED changes, and the
#    finish rule in CLAUDE.md is to commit with `Closes #<n>`. Without a starting sha the
#    gate would congratulate an agent for changing nothing.
#
# 2. DETECT UNATTRIBUTED DRIFT. The Stop hook writes a state fingerprint every time a turn
#    passes. If the codebase no longer matches that fingerprint, something changed while
#    nothing was accounting for it: a hand edit, another tool, or an agent that hit the
#    8-block Stop-hook override and exited leaving undeclared work behind. That last case
#    is the dangerous one, because it looks exactly like a clean finish.
#
#    Drift is REPORTED, never blocked. Refusing to let a turn begin would be worse than the
#    problem. The report goes to stdout, which Claude Code adds to the agent's context, so
#    the agent sees it before doing anything and can account for it or say plainly that it
#    was not responsible.
#
# Contract with Claude Code:
#   stdin  = JSON describing the prompt event (must be read, or the caller can block)
#   stdout = added to the agent's context
#   exit 0 = always. This hook never blocks a turn from starting.
#
# The fingerprint uses `git hash-object --stdin` rather than shasum/sha256sum, because it
# is guaranteed present wherever git is and behaves identically on macOS and Linux.

set -uo pipefail

cat >/dev/null

DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MARKER="$DIR/.claude/.turn-start"
DIRTY="$DIR/.claude/.turn-dirty"
LAST="$DIR/.claude/.last-seen"
LASTDIRTY="$DIR/.claude/.last-dirty"

mkdir -p "$DIR/.claude" 2>/dev/null

# ---------------------------------------------------------------- clear any surviving block
# A new user prompt is definitionally a new turn, so a finish block that still exists right now
# belongs to a turn that ended WITHOUT passing: interrupted, abandoned, or over the 8-block
# ceiling. The Stop hook only deletes the file on a pass, so those turns leak it forward.
#
# Why that matters. Claude Code refuses to Write a file it has not read this session, so the
# agent's Write fails, it falls back to Read then Edit, and merges the previous turn's claims
# with this turn's. Observed twice in PackMagic on 2026-07-30 and 2026-07-31. Consume-on-pass
# was necessary and not sufficient; this closes the remaining half.
rm -f "$DIR/.gate/finish-block.md" 2>/dev/null

# "NO_GIT" is a deliberate sentinel, not a silent fallback: the Stop hook treats it as a
# broken gate rather than as "nothing changed".
SHA=$(git -C "$DIR" rev-parse HEAD 2>/dev/null || echo "NO_GIT")

# Content-sensitive fingerprint of the whole working state: HEAD, the full diff against it,
# and the untracked file list. Untracked file CONTENTS are not hashed (too slow on a large
# tree); their presence or absence is.
# Shared state helpers. One definition, two callers: see lib-gate.sh for why.
. "$(dirname "${BASH_SOURCE[0]}")/lib-gate.sh"

NOW=$(gate_fingerprint)

# ---------------------------------------------------------------- drift report
if [ -f "$LAST" ]; then
  PREV=$(sed -nE 's/^fingerprint=//p' "$LAST" | head -1)
  PREV_AT=$(sed -nE 's/^at=//p' "$LAST" | head -1)
  PREV_SHA=$(sed -nE 's/^sha=//p' "$LAST" | head -1)

  if [ -n "$PREV" ] && [ "$PREV" != "$NOW" ]; then
    ALL=$(gate_dirty_diff "${LASTDIRTY}")

    # SEPARATE COMMITTED FROM DRIFTED.
    #
    # gate_dirty_diff reports every path that entered or left the uncommitted set. A path that
    # LEFT it because you committed is not drift, it is the correct disposition of the work.
    #
    # The previous message asserted "Committed work is NOT drift and is not listed here" while
    # listing exactly that. On 2026-07-31 an agent read the report, told the user that ten
    # committed files were "in-flight work never committed", and offered to help discard them.
    # Every word of that was false, and it came from this hook. A monitor that states
    # falsehoods is worse than no monitor, because it is believed.
    #
    # The test is exact: if a path changed between the sha recorded at the last pass and the
    # current HEAD, a commit moved it.
    COMMITTED=""
    DRIFTED="$ALL"
    if [ -n "${PREV_SHA:-}" ] && [ "$PREV_SHA" != "NO_GIT" ] && [ "$PREV_SHA" != "$SHA" ]; then
      SINCE=$(git -C "$DIR" diff "$PREV_SHA".."$SHA" --name-only 2>/dev/null || true)
      if [ -n "$SINCE" ]; then
        COMMITTED=$(printf '%s\n' "$ALL" | grep -Fxf  <(printf '%s\n' "$SINCE") || true)
        DRIFTED=$( printf '%s\n' "$ALL" | grep -Fxvf <(printf '%s\n' "$SINCE") || true)
      fi
    fi
    DRIFTED=$(printf   '%s\n' "$DRIFTED"   | sed '/^$/d')
    COMMITTED=$(printf '%s\n' "$COMMITTED" | sed '/^$/d')

    if [ -n "$DRIFTED" ]; then
      echo "UNATTRIBUTED CHANGES since the last verified turn (${PREV_AT:-unknown time})."
      echo "The codebase does not match the state recorded when a turn last passed the gate."
      echo "Something changed that no finish block accounted for: a hand edit, another tool,"
      echo "or a previous turn that hit the 8-block Stop-hook override and exited anyway."
      echo ""
      echo "Files that drifted, uncommitted and unaccounted for:"
      printf '%s\n' "$DRIFTED" | sed 's/^/  - /'
      if [ -n "$COMMITTED" ]; then
        echo ""
        echo "Also different since then, but moved by a COMMIT. This is not drift:"
        printf '%s\n' "$COMMITTED" | sed 's/^/  - /'
      fi
      echo ""
      echo "Do not silently absorb the drifted files into your own CHANGED list. Either account"
      echo "for them explicitly, or state that they predate this turn and you did not make them."
      echo ""
      echo "(Recorded to .claude/drift.log. This is a report, not a block.)"

      { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) drift since ${PREV_AT:-unknown}: $(printf '%s' "$DRIFTED" | tr '\n' ' ')"
      } >> "$DIR/.claude/drift.log"

    elif [ -n "$COMMITTED" ]; then
      # Fully explained by a commit. State it in one true line, and do NOT write it to
      # drift.log: logging a non-event is how a drift alarm becomes background noise, and a
      # drift alarm that is ignored is the same as no drift alarm.
      echo "$(printf '%s\n' "$COMMITTED" | wc -l | tr -d ' ') file(s) changed since the last verified turn, all of them by commit ${PREV_SHA:0:7}..${SHA:0:7}."
      echo "That is a commit, not drift. Nothing is unaccounted for and no action is needed."

    else
      echo "UNATTRIBUTED CHANGES since the last verified turn (${PREV_AT:-unknown time})."
      echo "No file names differ, so this is a content, mode or line-ending change that the"
      echo "name-level diff cannot see. Inspect with: git diff HEAD"
      echo ""
      echo "(Recorded to .claude/drift.log. This is a report, not a block.)"

      { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) drift since ${PREV_AT:-unknown}: (no name-level diff)"
      } >> "$DIR/.claude/drift.log"
    fi
  fi
fi

# ---------------------------------------------------------------- turn marker
# The DIRTY SNAPSHOT is what makes "changed this turn" honest. Without it the Stop hook diffs
# against the last COMMIT, which blames the agent for every pre-existing uncommitted edit and
# makes a read-only turn impossible to pass in a dirty repo. Observed in PackMagic 2026-07-30.
gate_dirty_snapshot > "$DIRTY"

{
  echo "sha=$SHA"
  echo "epoch=$(date +%s)"
  echo "at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$MARKER"

exit 0
