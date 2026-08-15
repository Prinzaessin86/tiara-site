#!/usr/bin/env bash
#
# `make gate-baseline`: record the CURRENT state as the verified baseline.
#
# The gate records this itself on every PASS, so you should rarely need this. It exists because
# the baseline only advances on a full pass: a long run of blocks leaves it stale, and a stale
# baseline makes the drift report fire on the same files every turn forever. Permanent noise
# trains you to ignore the alarm, which is worse than having no alarm.
#
# Use it after committing work the gate has been reporting as drift, or any time you have
# deliberately reconciled the tree by hand and want the gate to accept this as the new normal.
#
# It records only what is UNCOMMITTED. HEAD is not part of the fingerprint, because a commit is a
# recorded action and not unattributed drift.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

DIR="$(pwd)"
. .claude/hooks/lib-gate.sh

BEFORE="none"
[ -f .claude/.last-seen ] && BEFORE=$(sed -nE 's/^at=//p' .claude/.last-seen | head -1)

{
  echo "sha=$(git rev-parse HEAD 2>/dev/null || echo NO_GIT)"
  echo "at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "fingerprint=$(gate_fingerprint)"
} > .claude/.last-seen
gate_dirty_snapshot > .claude/.last-dirty

N=$(wc -l < .claude/.last-dirty | tr -d ' ')
echo "gate baseline re-recorded."
echo "  previous baseline: $BEFORE"
echo "  now:               $(sed -nE 's/^at=//p' .claude/.last-seen | head -1)"
echo "  uncommitted files accepted as the new normal: $N"
[ "$N" -gt 0 ] && { echo; echo "  Those files will no longer be reported as drift:"; awk '{ $1=""; sub(/^ /,""); print }' .claude/.last-dirty | sed 's/^/    /'; }
echo
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) baseline re-recorded by hand (was $BEFORE, $N uncommitted files accepted)" >> .claude/gate.log
