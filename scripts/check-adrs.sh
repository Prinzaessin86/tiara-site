#!/usr/bin/env bash
#
# check-adrs.sh  (FD-/AD- scheme)
#
# Keeps the decision log honest. Deterministic, fail closed. Adapted from the original
# NNNN checker to the FD-/AD- namespace: FD- for factory decisions, AD- for app decisions.
#
#   1. The id in the filename matches the id in the title (FD-NNNN or AD-NNNN).
#   2. Every ADR carries Status, Date, and "Enforced by"; the Status is one we allow.
#   3. Supersession is symmetric and may cross namespaces (an AD- may be superseded by an FD-).
#
# This is the executable half of FD-0000. See FD-0003 for why it fails closed.
# Allowed statuses: "Accepted" or "Superseded-by <id>", where <id> is FD-NNNN or AD-NNNN.
# Written for stock macOS bash 3.2 and BSD sed: no bash 4 features, no \| alternation.
# The FD/AD prefix is matched with the character class [FA]D, which BSD sed accepts.

set -euo pipefail
DIR="${1:-docs/decisions}"

if [ ! -d "$DIR" ]; then
  echo "check-adrs: decisions directory '$DIR' not found. Failing closed."
  exit 1
fi

FILES=$(find "$DIR" -type f -name '[FA]D-[0-9][0-9][0-9][0-9]-*.md' | sort)
if [ -z "$FILES" ]; then
  echo "check-adrs: no FD-/AD- ADR files found under '$DIR'. Failing closed."
  exit 1
fi

FAILED=0

status_of() {
  local id="$1" file
  file=$(find "$DIR" -type f -name "$id-*.md" | head -1)
  [ -z "$file" ] && return 0
  grep -m1 '^\*\*Status:\*\*' "$file" 2>/dev/null | sed 's/^\*\*Status:\*\* *//'
}
adr_exists() {
  local id="$1" file
  file=$(find "$DIR" -type f -name "$id-*.md" | head -1)
  [ -n "$file" ]
}

# ---- Checks 1 and 2, per file ----
for f in $FILES; do
  base=$(basename "$f")
  id=${base:0:7}   # FD-0001 or AD-0001

  title=$(grep -m1 '^# ' "$f" || true)
  if [ -z "$title" ]; then
    echo "check-adrs: $base has no '# <id>. Title' heading."; FAILED=1; continue
  fi
  title_id=$(echo "$title" | sed -n 's/^# \([FA]D-[0-9][0-9][0-9][0-9]\)\..*/\1/p')
  if [ "$title_id" != "$id" ]; then
    echo "check-adrs: $base filename says $id, title says '${title_id:-none}'."; FAILED=1
  fi

  for field in Status Date "Enforced by"; do
    if ! grep -qm1 "^\*\*${field}:\*\*" "$f"; then
      echo "check-adrs: $base has no '**${field}:**' line."; FAILED=1
    fi
  done

  status_line=$(grep -m1 '^\*\*Status:\*\*' "$f" || true)
  if [ -n "$status_line" ]; then
    status=$(echo "$status_line" | sed 's/^\*\*Status:\*\* *//')
    case "$status" in
      Accepted) ;;
      Superseded-by\ [FA]D-[0-9][0-9][0-9][0-9]) ;;
      *)
        echo "check-adrs: $base status '$status'. Allowed: 'Accepted' or 'Superseded-by FD-/AD-NNNN'."; FAILED=1 ;;
    esac
  fi
done

# ---- Check 3 forward: if A supersedes B, B must exist and record it ----
for f in $FILES; do
  base=$(basename "$f"); id=${base:0:7}
  sup_line=$(grep -m1 '^\*\*Supersedes:\*\*' "$f" || true)
  [ -z "$sup_line" ] && continue
  target=$(echo "$sup_line" | sed -n 's/^\*\*Supersedes:\*\* *\([FA]D-[0-9][0-9][0-9][0-9]\).*/\1/p')
  if [ -z "$target" ]; then
    echo "check-adrs: $base has a malformed Supersedes line: '$sup_line'."; FAILED=1; continue
  fi
  if ! adr_exists "$target"; then
    echo "check-adrs: $base supersedes $target, but no ADR $target exists."; FAILED=1; continue
  fi
  target_status=$(status_of "$target")
  expected="Superseded-by $id"
  if [ "$target_status" != "$expected" ]; then
    echo "check-adrs: $base supersedes $target, but $target status is '${target_status:-none}', expected '$expected'."; FAILED=1
  fi
done

# ---- Check 3 reverse: if B is superseded by A, A must exist and claim it ----
for f in $FILES; do
  base=$(basename "$f"); id=${base:0:7}
  status=$(status_of "$id")
  case "$status" in
    Superseded-by\ [FA]D-[0-9][0-9][0-9][0-9])
      by=$(echo "$status" | sed -n 's/^Superseded-by \([FA]D-[0-9][0-9][0-9][0-9]\)$/\1/p')
      if ! adr_exists "$by"; then
        echo "check-adrs: ADR $id says superseded by $by, but no ADR $by exists."; FAILED=1; continue
      fi
      byfile=$(find "$DIR" -type f -name "$by-*.md" | head -1)
      claim=$(grep -m1 '^\*\*Supersedes:\*\*' "$byfile" 2>/dev/null | sed -n 's/^\*\*Supersedes:\*\* *\([FA]D-[0-9][0-9][0-9][0-9]\).*/\1/p' || true)
      if [ "$claim" != "$id" ]; then
        echo "check-adrs: ADR $id says superseded by $by, but $by does not claim to supersede $id."; FAILED=1
      fi
      ;;
  esac
done

if [ "$FAILED" -eq 1 ]; then
  echo ""; echo "The decision log is inconsistent. Fix the ADRs above, then re-run."; exit 1
fi
count=$(echo "$FILES" | wc -l | tr -d ' ')
echo "check-adrs: $count ADRs, all consistent"
exit 0
