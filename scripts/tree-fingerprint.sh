#!/usr/bin/env bash
# Print a stable fingerprint of the working tree's tracked + untracked-non-ignored content.
#
# It hashes file CONTENT (and paths), not HEAD, so it is stable across a commit. Ignored files
# (build output, .verify-pass) are excluded, so a marker written from this never fingerprints itself.
#
# WHAT THIS NO LONGER CLAIMS. The header used to end by saying a subsequent push could compare this
# value to prove the code had not moved. That is the push leash, which FD-0014 replaced: an agent
# does not push at all, so there is nothing for a fingerprint to gate. Leaving it would have this
# file asserting a mechanism the factory decided against, which is worse than saying nothing,
# because a reader stops looking. (BOOT-93)
#
# The old sentence is PARAPHRASED here rather than quoted, deliberately. push-readiness.test.sh
# asserts the literal phrase is absent, and a comment reproducing it to explain its removal would
# match that grep and make the assertion permanently red. That is the anchored-on-a-comment trap
# .claude/rules/testing.md names, hit while writing this.
#
# The fingerprint still has a job: `.verify-pass` records which tree last passed, which is how a
# turn-level check can tell a green run from a stale one.
#
# Safe on an empty repo (shasum of an empty stream is a constant), and on paths with spaces
# (null-delimited read).
set -uo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "no-repo"; exit 0; }
cd "$root" || { echo "no-repo"; exit 0; }

git ls-files -z -co --exclude-standard 2>/dev/null \
  | while IFS= read -r -d '' f; do [ -f "$f" ] && shasum "$f"; done \
  | shasum | awk '{print $1}'
