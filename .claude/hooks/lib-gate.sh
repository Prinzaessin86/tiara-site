#!/bin/bash
#
# Shared state helpers for the finish gate. Sourced by turn-start.sh and verify-on-stop.sh.
#
# WHY THIS FILE EXISTS. The fingerprint was originally duplicated in both hooks with a comment
# saying "keep in step with the other one". Two copies of a rule kept in sync by hoping someone
# remembers is the precise failure this project exists to remove. One definition, two callers.
#
# Requires: DIR set by the caller.

# The gate's OWN output. Excluded from "what changed", because otherwise every turn is blocked
# for failing to declare the log file the block was just written to, and the screenshot captured
# to satisfy the device check. Evidence is not work.
GATE_NOISE='^(\.claude/(\.turn-start|\.turn-dirty|\.last-dirty|\.last-seen|gate\.log|override\.log|drift\.log)|\.artifacts/|\.gate/)'

# The same exclusion as a git pathspec. Needed because these files may be TRACKED (someone runs
# `git add -A`), in which case they appear in `git diff HEAD` and a name-list grep never sees them.
GATE_PATHSPEC=(':(exclude).claude/.turn-start' ':(exclude).claude/.turn-dirty'
               ':(exclude).claude/.last-dirty' ':(exclude).claude/.last-seen'
               ':(exclude).gate'
               ':(exclude).claude/gate.log'    ':(exclude).claude/override.log'
               ':(exclude).claude/drift.log'   ':(exclude).artifacts')

# CAREFUL: every `grep -v` here is wrapped in `{ ... || true; }`.
#
# grep exits 1 when it outputs no lines, which is not an error: it is what happens when the
# untracked list is empty or is entirely gate noise. Under `set -o pipefail` that status
# propagates to the whole pipeline, so a trailing `|| echo NO_FINGERPRINT` fired even though
# hash-object had already printed a valid hash. The result was "<valid hash>\nNO_FINGERPRINT",
# which never matched the stored value, so drift was reported EXACTLY when the tree was clean.
# No error, no red output, a plausible answer, silently wrong. Do not remove these guards.
_filter() { grep -vE "$GATE_NOISE" || true; }

# ---------------------------------------------------------------------------------------------
# DIRTY SNAPSHOT: one line per uncommitted file, "<blob-hash> <path>".
#
# This is what makes "changed THIS TURN" honest. The first version diffed against the turn's
# starting COMMIT, which counted every pre-existing uncommitted change as this turn's work. In a
# dirty repo a read-only turn could never pass, and worse, an agent got blamed for edits made
# before it started. Hashing the dirty set at turn start and comparing at the end fixes that.
#
# Dirty sets are small, so hashing each file is cheap.
# ---------------------------------------------------------------------------------------------
gate_dirty_snapshot() {
  # BOOT-69: core.quotePath=false, or git C-quotes any non-ASCII path ("Str\303\266m.swift"). The
  # quoted form then fails the [ -f ] test below, is recorded as DELETED, is never hashed, and
  # reports as changed on every turn forever, including turns that changed nothing.
  { git -C "$DIR" -c core.quotePath=false diff HEAD --name-only -- . "${GATE_PATHSPEC[@]}" 2>/dev/null
    git -C "$DIR" -c core.quotePath=false ls-files -o --exclude-standard 2>/dev/null | _filter
  } | sed '/^$/d' | sort -u | while IFS= read -r f; do
      if [ -f "$DIR/$f" ]; then
        printf '%s %s\n' "$(git -C "$DIR" hash-object "$DIR/$f" 2>/dev/null || echo UNREADABLE)" "$f"
      else
        printf 'DELETED %s\n' "$f"
      fi
    done
}

# What this turn actually changed. $1 = starting sha, $2 = path to the starting dirty snapshot.
#
# Three ways a file counts:
#   - committed between the starting sha and HEAD
#   - dirty now with a different hash than at turn start, or newly dirty
#   - dirty at turn start and no longer dirty (the turn reverted it)
#
# A file that was already dirty and is untouched does NOT count. That is the whole point.
gate_dirty_diff() {   # $1 = a recorded snapshot file
  local snap="$1" cur
  cur=$(gate_dirty_snapshot)
  { printf '%s\n' "$cur" | while IFS=' ' read -r h f; do
      [ -z "${f:-}" ] && continue
      # BOOT-69: field 2 is only the whole path when the path has no space in it. `My File.swift`
      # never matched its own snapshot line, so it reported as changed on every turn forever. Take
      # the first field as the hash and EVERYTHING after the first space as the path.
      prev=$(awk -v p="$f" '{h=$1; sub(/^[^ ]+ /,""); if ($0==p) {print h; exit}}' "$snap" 2>/dev/null || true)
      [ "$h" != "$prev" ] && printf '%s\n' "$f"
    done
    awk '{ $1=""; sub(/^ /,""); print }' "$snap" 2>/dev/null | while IFS= read -r f; do
      [ -z "${f:-}" ] && continue
      printf '%s\n' "$cur" | awk -v p="$f" '{sub(/^[^ ]+ /,""); if ($0==p) x=1} END{exit x?0:1}' || printf '%s\n' "$f"
    done
  } | sed '/^$/d' | _filter | sort -u
}

# What this turn changed: committed during the turn, plus anything the dirty set says moved.
gate_changed_this_turn() {
  local start_sha="$1" snap="$2"
  { if [ -n "$start_sha" ] && [ "$start_sha" != "NO_GIT" ]; then
      git -C "$DIR" diff --name-only "$start_sha" HEAD -- . "${GATE_PATHSPEC[@]}" 2>/dev/null
    fi
    gate_dirty_diff "$snap"
  } | sed '/^$/d' | _filter | sort -u
}

# ---------------------------------------------------------------------------------------------
# FINGERPRINT of the whole working state, for unattributed-drift detection between sessions.
# `git hash-object --stdin` rather than shasum/sha256sum: guaranteed present wherever git is,
# and byte-identical on macOS and Linux.
# ---------------------------------------------------------------------------------------------
# Fingerprint of the DIRTY SET ONLY, for unattributed-drift detection.
#
# HEAD is deliberately EXCLUDED. The first version hashed HEAD too, so the moment anything was
# committed the fingerprint differed from the recorded one forever and the drift report could
# never go quiet again. Observed in PackMagic 2026-07-30: after committing the gate install, the
# same 17 files reported as unattributed drift on every single turn, which produced an 11-block
# run and an agent giving up. Permanent noise trains you to ignore the alarm, which is worse than
# having no alarm.
#
# A commit is a RECORDED action. It is the opposite of unattributed. Drift is about uncommitted
# mystery changes: a hand edit, another tool, or a turn that hit the 8-block override and exited
# leaving work behind. Commits are discoverable in git log and do not belong here.
gate_fingerprint() {
  local out
  out=$(gate_dirty_snapshot | git -C "$DIR" hash-object --stdin 2>/dev/null)
  if [ -n "$out" ]; then printf '%s' "$out"; else printf 'NO_FINGERPRINT'; fi
}
