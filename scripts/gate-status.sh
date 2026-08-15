#!/usr/bin/env bash
#
# `make gate-status`: did the finish gate run, and what did it catch?
#
# The gate is silent when it passes, which means a gate that is NOT RUNNING looks exactly
# like a gate that is passing. A typo in .claude/settings.json, a missing execute bit, or a
# wrong path all produce silence. This script exists so "is it alive" is one command instead
# of an assumption.
#
# If it reports no log at all, treat that as BROKEN, not as clean.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

LOG=.claude/gate.log
DRIFT=.claude/drift.log
OVR=.claude/override.log

echo "── finish gate · $(basename "$PWD") ──"

if [ ! -f "$LOG" ]; then
  echo
  # An archived log means the gate HAS run; only the current log is fresh. Saying "never run"
  # in that case sends you diagnosing a dead gate that is alive. It did exactly that on
  # 2026-07-30, right after gate.log was archived to gate.log.pre-stable.
  ARCH=$(ls "$LOG".* 2>/dev/null | tr '\n' ' ')
  if [ -n "$ARCH" ]; then
    echo "  No current gate.log, but archived logs sit beside it: $ARCH"
    echo "  So the gate has run before. This is a FRESH log, not a dead gate."
    echo "  It still has to prove itself alive: run one turn, then check again."
    echo
    exit 0
  fi
  echo "  NO gate.log, and no archive. The gate has never run in this repo."
  echo
  echo "  Do not read this as 'nothing to report'. A gate that is not running is silent,"
  echo "  and so is a gate that passes. Check:"
  echo "    - .claude/settings.json has a Stop hook AND a UserPromptSubmit hook"
  echo "    - .claude/hooks/*.sh are executable  (ls -l .claude/hooks)"
  echo "    - run 'claude --debug' and watch for the hooks firing on one turn"
  exit 0
fi

# COUNT EVENTS, NOT STRING OCCURRENCES.
#
# The old version counted overrides with `grep -c " OVERRIDE"` over gate.log. Every BLOCK
# message contains the word three times in its own help text, so three blocks reported nine
# overrides, and the number grew with every block. The real record is override.log, which had
# four. The single most important signal here, a human waiving a check, was the one that lied.
# Found 2026-07-31.
EVENT='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z '
events() { [ -f "$2" ] && { grep -cE "$1" "$2" 2>/dev/null || echo 0; } || echo 0; }

P=$(events "${EVENT}PASS" "$LOG")
B=$(events "${EVENT}BLOCK" "$LOG")
O=$(events "$EVENT" "$OVR")
D=$(events "$EVENT" "$DRIFT")
N=$((P + B))

# A bounded view states its bound (D13). The old one ran `tail -15` on a log whose BLOCK
# entries are fourteen lines each, so "last 15 turns" showed three.
SHOW=12
echo
echo "  last $SHOW of $N gate outcomes"
grep -E "${EVENT}(PASS|BLOCK)" "$LOG" 2>/dev/null | cut -c1-104 | tail -"$SHOW" | sed 's/^/    /'

echo
printf '  passes %s · blocks %s · overrides %s · drift events %s\n' "$P" "$B" "$O" "$D"

if [ "$B" -gt 0 ]; then
  echo
  echo "  blocks by reason"
  grep -E "${EVENT}BLOCK " "$LOG" 2>/dev/null \
    | sed -E 's/^[^ ]+ BLOCK //' | cut -c1-58 \
    | sort | uniq -c | sort -rn | head -8 | sed 's/^/    /'
fi

# Eight consecutive blocks with no PASS after them is Claude Code's documented override
# firing: the turn ended anyway. That used to be invisible. It is the signature of an agent
# that gave up, and it must not read as success.
RUN=$(awk '/Z BLOCK /{n++; if(n>m) m=n} /Z PASS$/{n=0} END{print m+0}' "$LOG")
if [ "${RUN:-0}" -ge 8 ]; then
  echo
  echo "  ⚠ longest run of consecutive blocks: $RUN"
  echo "    8 or more means Claude Code overrode the hook and ended the turn anyway."
  echo "    That is an agent giving up, not finishing. Check what it was stuck on."
fi

if [ "$O" -gt 0 ]; then
  echo
  echo "  overrides (claim checks waived by a human), last 5 of $O"
  tail -5 "$OVR" 2>/dev/null | sed 's/^/    /'
fi

if [ "$D" -gt 0 ]; then
  echo
  echo "  unattributed drift (changes no finish block accounted for), last 5 of $D"
  echo "  Committed work is excluded from this list by turn-start.sh, so every line here is"
  echo "  genuinely uncommitted and unaccounted for."
  tail -5 "$DRIFT" 2>/dev/null | cut -c1-100 | sed 's/^/    /'
fi

echo
