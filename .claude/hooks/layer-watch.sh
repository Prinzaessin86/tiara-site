#!/bin/bash
#
# FileChanged hook. Alarms, never blocks, when a file the enforcement layer depends on is written
# by ANYTHING: this agent, another session, a background process, a hand edit, a `make` target.
#
# WHAT THIS DOES NOT DO, first, because the honest version of this hook is a narrow one.
#
# The finish gate ALREADY catches an agent's own edit to any of these four files, and BLOCKS on it.
# Makefile, .gitignore and the manifest are in neither GATE_NOISE (lib-gate.sh:14) nor
# GATE_BUILD_NOISE (lib-gate.sh:38), so they land in gate_changed_this_turn and verify-on-stop
# refuses the turn when CHANGED omits them (verify-on-stop.sh:244-265). This hook is NOT the thing
# that catches that, and it is weaker than the thing that does, because it cannot block.
#
# Its delta is the three cases a turn boundary cannot see:
#   1. A write that is not a tool call in this turn. turn-start.sh:103-124 reports that as drift,
#      but only at the START OF THE NEXT PROMPT.
#   2. A write made and reverted inside one turn. gate_fingerprint hashes content, not events, so
#      it is structurally blind to that.
#   3. A write while a long turn is still running, when the operator can still intervene.
#
# WHAT IT WATCHES AND WHY. Not "the files S7 leaves out": S7 is dead, and the manifest that exists
# (.claude/.enforcement-manifest, read 2026-08-17) covers 15 paths, carries no mode column and does
# not hash itself. These four are what it leaves out, plus the wiring:
#
#   Makefile        the gate's entry point. Nothing hashes it. `make verify` can be redefined and
#                   conform.sh still reports no drift, because it was never in the manifest.
#   .gitignore      one of the four --exclude-standard inputs that lib-gate.sh:18-24 records as
#                   having been editable by the thing being gated. Not in the manifest either.
#   settings.json   the wiring. Emptying its hooks[] arrays disarms the layer with all six files
#                   still present and still executable (_bootstrap#148, hook-liveness.sh:51-56).
#   the manifest    the inventory. It does not hash itself, so a rewrite of it is self-consistent
#                   and conform.sh reports nothing.
#
# HOW THE WIRING WORKS. Not obvious, and getting it wrong makes this hook silent. Read out of the
# shipped binary, 2.1.233, build 2026-08-14T17:21:48Z.
#
#   `matcher` does TWO jobs with TWO different meanings.
#   a) It SEEDS THE WATCH LIST. The bundle splits matcher on "|", trims each part, and joins the
#      relative ones to the project dir. So the matcher must contain the real RELATIVE PATHS.
#      hookSpecificOutput.watchPaths is additive and is NOT required; no SessionStart shim is
#      needed to make this hook fire.
#   b) It FILTERS which hooks run, by matching matcher against basename(file_path). FileChanged is
#      not in the tool-event set, so a matcher containing "." or "/" is compiled as a REGEX and
#      tested against the BASENAME ALONE.
#   Consequence: a lone ".claude/settings.json" seeds the right watch path and then NEVER FIRES,
#   because the basename is "settings.json". The matcher in settings.json therefore lists BOTH
#   spellings of each nested file. The bare spellings also seed two watch paths at the repo root
#   which normally do not exist; that is harmless, and it means a settings.json or an
#   enforcement-manifest dropped at the repo root alarms too.
#
#   OUTPUT CONTRACT, and why this prints JSON rather than a sentence. For a hook that exits 0 the
#   bundle sets output=stdout, but the FileChanged consumer only forwards `output` when the hook
#   FAILED. A successful hook's plain stdout is DISCARDED. The only thing a successful FileChanged
#   hook can say to the operator is the `systemMessage` field of a JSON object on stdout. So: JSON,
#   or silence.
#
# NEVER BLOCKS, for two reasons, the second load-bearing.
#   1. The brief asks for non-blocking, to avoid the false-positive class the gate design avoids.
#   2. It could not block anyway. The write has already happened when chokidar reports it. Exit 2
#      sets `blocked` on the result record and the FileChanged consumer never reads that field.
#
# FAILING CLOSED, for a hook that cannot block, means ALARMING when it cannot tell rather than
# going quiet. Every unparseable, unreadable or unexpected input below produces an alarm.
#
# Contract with Claude Code:
#   stdin  = JSON: session_id, transcript_path, cwd, hook_event_name, file_path,
#            event in "change" | "add" | "unlink"
#   stdout = {"systemMessage":"..."} to alarm, nothing at all to stay quiet
#   exit 0 = always

set -uo pipefail

DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# JSON-escape for the systemMessage payload. Deliberately NOT a jq or python3 call: one of the
# alarm paths below exists precisely because no parser is available, so the alarm's own encoder
# must not need one. Handles the only characters that occur here: backslash, quote, newline.
esc() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}'
}

alarm() { printf '{"systemMessage":"%s"}\n' "$(esc "$1")"; exit 0; }

INPUT=$(cat)
BYHAND="Inspect by hand: git status --short"

[ -n "$INPUT" ] || alarm "LAYER WATCH: a watched file changed and this hook received no input, so it cannot say which. $BYHAND"

FILE_PATH=""
EVENT=""
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.file_path // empty' 2>/dev/null)
  EVENT=$(printf '%s' "$INPUT" | jq -r '.event // empty' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | python3 -c \
    'import sys,json; d=json.load(sys.stdin); print(d.get("file_path",""))' 2>/dev/null)
  EVENT=$(printf '%s' "$INPUT" | python3 -c \
    'import sys,json; d=json.load(sys.stdin); print(d.get("event",""))' 2>/dev/null)
else
  alarm "LAYER WATCH: a watched file changed and no JSON parser (jq or python3) is available, so this hook cannot say which. $BYHAND"
fi

[ -n "$FILE_PATH" ] || alarm "LAYER WATCH: a watched file changed and its path could not be extracted from the hook input. $BYHAND"

REL="${FILE_PATH#"$DIR"/}"

# ------------------------------------------------------------- the one silence that is earned
#
# Suppress when the file on disk is byte-identical to HEAD. That is a revert, a `touch`, a
# `git checkout`, a branch switch, or a tool rewriting a file to what it already said. None of
# those changes the layer, and alarming on them is exactly how an alarm becomes background noise.
# lib-gate.sh:132-137 records that happening to the drift report, and the consequence there was an
# 11-block run and an agent giving up.
#
# Deliberately narrow. It does NOT suppress on "the file is tracked", on "git status is clean", or
# on "the change is small". Only on identical content.
#
# An unlink is NEVER suppressed: a deleted file has no content to compare, and deletion of any of
# these four is the loudest case there is.
if [ "$EVENT" != "unlink" ] && [ -f "$FILE_PATH" ]; then
  NOW_HASH=$(git -C "$DIR" hash-object "$FILE_PATH" 2>/dev/null || true)
  HEAD_HASH=$(git -C "$DIR" rev-parse "HEAD:$REL" 2>/dev/null || true)
  if [ -n "$NOW_HASH" ] && [ "$NOW_HASH" = "$HEAD_HASH" ]; then
    exit 0
  fi
fi

case "$EVENT" in
  unlink) VERB="DELETED" ;;
  add)    VERB="CREATED" ;;
  *)      VERB="WRITTEN" ;;
esac

# One sentence per file, naming the rule and one concrete next action. Generic text would be worse
# than nothing: "a watched file changed" leaves the operator to work out which rule she just lost.
case "$REL" in
  Makefile)
    WHY="The Makefile is the gate's entry point and is NOT in the enforcement manifest, so nothing hashes it and 'make verify' can be redefined without conform.sh reporting drift."
    FIX="Check it: git diff -- Makefile" ;;
  .gitignore)
    WHY=".gitignore is one of the four --exclude-standard inputs that were editable by the thing being gated (_bootstrap#151), and it is NOT in the enforcement manifest."
    FIX="Check it: git diff -- .gitignore" ;;
  .claude/settings.json|settings.json)
    WHY="settings.json is the wiring. Emptying its hooks[] arrays disarms every hook while all six files stay present and executable (_bootstrap#148)."
    FIX="Check the layer is still wired: bash scripts/hook-liveness.sh" ;;
  .claude/.enforcement-manifest|.enforcement-manifest|enforcement-manifest)
    WHY="The manifest is the inventory conform.sh checks against, and it does not hash itself, so a rewrite of it is self-consistent and reports no drift."
    FIX="Re-check the layer against the factory: bash scripts/verify-enforcement-install.sh ." ;;
  *)
    # Reached only if the settings.json matcher and this case list drift apart. Alarm rather than
    # go quiet: a watched file with no rule text means the two halves no longer agree.
    WHY="This file is watched by layer-watch but has no rule text in the hook, which means the settings.json matcher and this hook no longer agree."
    FIX="Check it: git diff -- '$REL'" ;;
esac

alarm "LAYER WATCH: $REL was $VERB.
$WHY
$FIX
This is an alarm, not a refusal. The write already happened and nothing was blocked."
