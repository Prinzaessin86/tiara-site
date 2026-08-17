#!/bin/bash
#
# SessionStart hook. Runs the S6 liveness probe once, before the first tool call of the session,
# and SURFACES a disarmed layer. It cannot refuse the session.
#
# IT CANNOT BLOCK, and this is measured rather than assumed. In the shipped binary (2.1.233) a
# hook exit of 2 produces outcome:"blocking" at the executor for every event, but the SessionStart
# consumer routes it through s2r(), which builds a `hook_non_blocking_error` attachment:
#
#     if(m.blockingError) l.push(s2r("SessionStart", m.blockingError, `SessionStart:${t}`));
#     function s2r(e,t,r=e){ return vc({type:"hook_non_blocking_error", ... }) }
#
# The session proceeds either way, confirmed live: a SessionStart hook doing `exit 2` returned
# is_error:false and the session ran to completion. So the exit code here is not about blocking.
# It is about WHO READS THE ALARM, and the two routes reach different audiences.
#
# WHY THIS EXITS 0 AND PRINTS JSON, rather than exiting 2 and printing to stderr. Measured across
# six headless sessions, not inferred:
#
#   exit 2, stderr   -> hook_non_blocking_error attachment. stdout is DISCARDED entirely
#                       ("stdout":"" in the transcript record). The terminal renders the hook name
#                       and stderr in ERROR colour, so the OPERATOR sees it. The model conversion
#                       is `hook_non_blocking_error:()=>[]`, so THE AGENT IS TOLD NOTHING. Verified:
#                       the model's reply was exactly "NONE".
#   exit 0, JSON     -> two attachments, cleanly split by audience.
#                       `systemMessage`            -> hook_system_message. Model conversion is
#                                                     `hook_system_message:()=>[]`, so the agent
#                                                     sees nothing; the TUI renders
#                                                     "{hookName} says: {content}" to the OPERATOR.
#                       hookSpecificOutput
#                         .additionalContext       -> hook_additional_context. Reaches THE MODEL as
#                                                     "SessionStart hook additional context: ...".
#                                                     Verified: the model quoted it back verbatim.
#
# So exit 0 with JSON reaches BOTH audiences, and exit 2 reaches only one. The agent about to make
# the first tool call of the session is the party that most needs to know the guards may be failing
# open, so telling only the operator was the wrong choice. An earlier version of this hook exited 2
# on the strength of an inference from wxi() that systemMessage was dropped for SessionStart. That
# inference was wrong: wxi() handles only terminalSequence and only on the http and mcp_tool paths,
# while command hooks go through y9n() and the QZf loop, which does emit the attachment.
#
# FAIL-CLOSED IS PRESERVED by exiting 0. If anything in this script crashes, it exits non-zero and
# the harness surfaces it on the old stderr route anyway; if it emits malformed JSON, the bundle
# throws on `kxi(A.stdout)` and that surfaces too. Silence requires the script to run to completion
# and deliberately print nothing, which happens only when the probe returned 0.
#
# scripts/hook-liveness.sh writes ZERO bytes to stderr (grep -c '>&2' = 0), so the probe's own
# output has to be captured with 2>&1 either way.
#
# WHAT THIS IS WORTH, stated narrowly, because most of it already exists.
# scripts/conform.sh:494-500 ALREADY runs this same probe and calls bad() on failure; Makefile:81
# is `verify: conform adrs tests`; verify-on-stop.sh:294 runs `make verify` on every turn that ends
# and BLOCKS when it is red. So the probe already runs, blocking, at every turn boundary.
#
# The only thing this adds is the window between session start and the first Stop. In that window a
# disarmed layer fails open on real tool calls and nothing notices until the turn ends, by which
# time the calls have run. That window is the whole product. It is not a second line of defence and
# it is not a replacement for conform.
#
# WHAT IT CANNOT CATCH, and the first one is structural.
#   - The settings.json disarm (_bootstrap#148). This hook is wired in the same settings.json it is
#     auditing. Empty every hooks[] array and this entry goes with them, so it never runs. A hook
#     cannot audit its own wiring from inside that wiring. layer-watch covers settings.json writes
#     from the other side; nothing covers both.
#   - A repo with .claude/hooks present and .claude/settings.json ABSENT. hook-liveness.sh:57 wraps
#     the entire wiring check in `if [ -f "$SETTINGS" ]`, so that state exits 0 and prints "the
#     enforcement layer can run and is refusing". Code-read, not executed.
#   - Anything about CONTENT. This asks whether the layer can run, never whether it is the layer
#     the factory shipped. conform's manifest check is what answers that.
#
# MEASURED COST, so it can be weighed rather than discovered.
#   - 0.48s wall clock on a cold copy of template/, once per session. Against Makefile:49's 33s
#     ceiling that is 1.5%, and it is not on the finish-gate path at all.
#   - hook-liveness.sh:97-98 invokes guard-bash.sh with `rm -rf /` to prove it still refuses, and
#     guard-bash.sh:26-27 appends every denial to .claude/gate.log. So each session fabricates one
#     `deny  recursive delete from root  rm -rf /` line into the log that
#     scripts/compliance-explain.mjs:212 tells the operator to grep. The note line below exists so
#     that entry is self-explaining. Delete it if you would rather have a quieter log.
#
# Contract with Claude Code:
#   stdin  = JSON: session_id, transcript_path, cwd, hook_event_name, source, ...
#   stdout = nothing at all when the layer is enforcing. A SessionStart hook that prints on every
#            session gets ignored. When it is not enforcing, one JSON object carrying both a
#            systemMessage for the operator and an additionalContext for the agent.
#   stderr = nothing, deliberately. Anything here means the script itself broke.
#   exit 0 = always, on both paths. See FAIL-CLOSED above for why that is still fail-closed.

set -uo pipefail

cat >/dev/null

DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROBE="$DIR/scripts/hook-liveness.sh"
LOG="$DIR/.claude/gate.log"

# JSON-escape, same helper and same reasoning as layer-watch.sh: one of the states this hook
# reports is "python3 is not on PATH", so the encoder for that message must not need python3.
esc() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}'
}

# $1 = the probe detail, already indented. Two audiences, two fields, one object.
#
# The operator gets the diagnosis and the commands, because she is the one who can run them and
# the agent is forbidden to: `chmod` is in permissions.deny and .claude/ is refused by guard-scope
# and by guard-bash R6. Telling the agent to chmod would be telling it to do a thing the layer
# exists to stop it doing.
#
# The agent gets a shorter statement of the same fact plus the one instruction that is actually
# its to follow: stop, say so, do not treat a silent guard as an absent rule.
alarm() {
  OPERATOR="SESSION FLOOR: the enforcement layer in $DIR is not verifiably enforcing.

$1

Nothing has been blocked. This session has started and the guards may be failing OPEN, which looks
identical to them passing. Fix before editing anything:
  chmod +x .claude/hooks/*.sh          if a hook lost its execute bit
  bash scripts/hook-liveness.sh        to re-check
  bash ~/Developer/_bootstrap/scripts/install-enforcement.sh .   if a file is missing"

  AGENT="SESSION FLOOR: the enforcement layer in this repo is not verifiably enforcing, so the
guards that normally refuse unsafe work may be failing OPEN for this session. A guard that is
silent because it cannot run looks exactly like a guard that had nothing to refuse. Do not read
the absence of a refusal as permission. Say this to the operator before your first edit, and do
not attempt to repair the layer yourself: chmod is denied to you and .claude/ is not yours to
write. The detail is:

$1"

  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "$(esc "$OPERATOR")" "$(esc "$AGENT")"
  exit 0
}

[ -f "$PROBE" ] || alarm "  scripts/hook-liveness.sh is MISSING, so the layer cannot be probed at all.
  A repo with no liveness probe cannot tell an armed layer from a disarmed one."

# python3 is checked BEFORE running the probe, not after, because hook-liveness.sh:59-76 runs its
# wiring check as a python3 here-document and does NOT distinguish "python3 is absent" from "no
# hooks are wired": on absence `wired` is empty rather than PARSE_FAILED, and every hook is then
# reported NOT WIRED. That fails closed with a false diagnosis, which is worse than failing closed
# with a true one. Say the true thing instead.
if ! command -v python3 >/dev/null 2>&1; then
  alarm "  python3 is not on PATH, and scripts/hook-liveness.sh parses settings.json with it.
  The wiring half of the probe cannot run, and the probe reports NOT WIRED for every hook when
  that happens, which is not a finding about your repo. Liveness is NOT VERIFIED here."
fi

# Invoked DIRECTLY, not via `bash`, for the reason hook-liveness.sh:16-21 gives about itself: a
# probe run through an interpreter reports healthy on a file with no execute bit, because bash will
# happily interpret it. The harness uses the direct form. rc 126 or 127 here means the probe itself
# has been disarmed, which is exactly the failure being looked for, and is caught below with
# everything else.
OUT=$("$PROBE" 2>&1)
RC=$?

[ "$RC" = 0 ] && exit 0

# One annotated line so the synthetic `rm -rf /` the probe just wrote to gate.log is readable as
# what it is, rather than as a real refusal, by anyone following
# scripts/compliance-explain.mjs:212.
#
# THE REDIRECTION ORDER HERE IS LOAD-BEARING and was wrong in the first version. `printf ... >>
# "$LOG" 2>/dev/null` does NOT suppress the failure to OPEN $LOG, because bash applies
# redirections left to right and the append is attempted before stderr is pointed at /dev/null.
# Measured: in a repo with no .claude directory the hook printed
# "...: No such file or directory" onto its own stderr, ahead of its alarm. `2>/dev/null` must
# come FIRST. The directory test is belt and braces on top of that.
if [ -d "${LOG%/*}" ]; then
  printf '%s\tnote\tsession-floor probe ran; any rm -rf / deny immediately above is synthetic\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null >> "$LOG" || true
fi

alarm "$(printf '%s\n' "$OUT" | sed 's/^/  /')"
