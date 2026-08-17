#!/bin/bash
#
# PreToolUse hook, fires on every Bash command the agent tries to run.
#
# Contract with Claude Code:
#   stdin  = JSON describing the tool call
#   exit 0 = allow
#   exit 2 = BLOCK, and send stderr back to the agent so it knows why
#
# THIS HOOK FAILS CLOSED.
#
# If it cannot read its input, if its JSON parser is missing, if anything at all is
# wrong with it, it BLOCKS. A safety gate that breaks quietly and starts allowing
# everything is worse than no gate at all, because you will still trust it.
# A gate that allows everything is indistinguishable from a gate with nothing to block.

set -uo pipefail

deny() {
  echo "BLOCKED by guard-bash: $1" >&2
  [ $# -gt 1 ] && echo "Command was: $2" >&2
  # A denial that leaves no trace cannot be counted, and an uncounted rule cannot be judged. The
  # cross-project guard refused the documented board command in five repos for ten days and nothing
  # anywhere recorded it. Appends only, swallows its own errors, and never changes the outcome:
  # a guard that failed because logging failed would be worse than no log. (BOOT-31)
  printf '%s\tdeny\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "${2:-}" \
    >> "${CLAUDE_PROJECT_DIR:-.}/.claude/gate.log" 2>/dev/null || true
  exit 2
}

INPUT=$(cat)
[ -n "$INPUT" ] || deny "no input received. Failing closed."

# --- Parse, with no single point of failure ---------------------------------
# jq is not guaranteed to be installed. python3 ships with the Xcode command line
# tools. If neither exists we do not guess, we block.
CMD=""
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || \
    deny "jq failed to parse hook input. Failing closed."
elif command -v python3 >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | python3 -c \
    'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null) || \
    deny "python3 failed to parse hook input. Failing closed."
else
  deny "no JSON parser available (need jq or python3). Failing closed. Run: brew install jq"
fi

[ -n "$CMD" ] || deny "could not extract a command from hook input. Failing closed."

# BOOT-64: tokens matched in RAW command text let any shell quoting split the literal without
# changing what the shell runs. Defined HERE rather than at section 4, because every path lock
# below needs it, and the rules that could not reach it are exactly the ones that had holes
# (BOOT-92, BOOT-113).
CMD_FLAT=$(printf '%s' "$CMD" | tr -d "\"'\\")

# BOOT-73 / BOOT-92: ONE list of mutating verbs, used by every path lock below. Enumerating
# redirect spellings per rule is what left the holes; a single list is fixed in one place.
# Deliberately conservative: `cp CLAUDE.md /tmp/backup` is a read and this refuses it too.
mutating_verb() {
  case "$CMD_FLAT" in
    *"sed -i"*|*"perl -pi"*|*"perl -i"*|*"awk -i"*|*"python3 -c"*|*"python -c"*|*"ruby -e"* \
    |"cp "*|*" cp "*|"mv "*|*" mv "*|"patch "*|*" patch "*|"install "*|*" install "* \
    |"dd "*|*" dd "*|"truncate "*|*" truncate "*|"ex -s"*|*" ex -s"*|*"tee "* \
    |"touch "*|*" touch "*|"rm "*|*" rm "*|*"rm -"*) return 0 ;;
  esac
  return 1
}

# --- 1. Irreversible destruction --------------------------------------------
# The agent has no undo. Neither do you.
case "$CMD_FLAT" in
  *"rm -rf /"*)          deny "recursive delete from root" "$CMD" ;;
  *"rm -rf ~"*)          deny "recursive delete of home" "$CMD" ;;
  *"git push --force"*)  deny "force push. rewrite history by hand or not at all" "$CMD" ;;
  *"git reset --hard"*)  deny "hard reset discards uncommitted work" "$CMD" ;;
  *"git clean -"*)       deny "git clean permanently deletes untracked files" "$CMD" ;;
  *"git checkout ."*)    deny "this silently discards every uncommitted change" "$CMD" ;;
esac

# --- 1b. The agent push refusal (FD-0014) ------------------------------------
# An agent does not push to a landing branch. Not "pushes verified code", not "pushes when a
# fingerprint matches": does not push. A person bypasses by running the push with the ! prefix,
# which does not go through hooks at all.
#
# WHAT THIS REPLACED, AND WHY THE OLD SHAPE WAS WORSE THAN NO RULE.
#
# This was a leash: `make verify` recorded .verify-pass, a fingerprint of the tree it passed on, and
# a push to main was allowed when the current tree still matched. Half of it was never built. No
# Makefile in any repo wrote the file, so `expected` was always empty, the comparison never matched,
# and every agent push was refused with a message naming a remedy that did nothing. BOOT-90 and
# _ticketflow#12 were both filed to add the missing write, and both were correct at the time.
#
# FD-0014 then decided the simpler thing. The estate believed pushes were verify-gated when nothing
# was gated, and a gate that is unsatisfiable is more dangerous than one that is absent, because
# absence is visible. So the comparison is DELETED rather than repaired, and there is nothing left
# to satisfy: the rule is the rule.
#
# THE BRANCH TEST STAYS, deliberately. FD-0014's acceptance says "a landing branch", and that is
# main. A push to a feature branch is still allowed, which is the difference between a leash and a
# wall: an agent can put work somewhere a human can see and merge it. (BOOT-93)
#
# BOOT-56 is still why the branch is read with `git -C "$PROJECT_DIR"` rather than from process CWD.
# The old leash read the Makefile and ran tree-fingerprint.sh relative to CWD while the project came
# from CLAUDE_PROJECT_DIR, so from any subdirectory it found nothing and the push went through. That
# whole class is gone with the file reads, but the branch lookup would have the same fault, silently
# and in the permissive direction.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$CMD" in
  *"git push"*)
    branch=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ "$branch" = "main" ]; then
      deny "an agent does not push to main (FD-0014). There is nothing to satisfy and no verify to run: publishing is a human act. A feature branch is fine, so push there and ask for a merge, or a human runs: ! git push" "$CMD"
    fi
    ;;
esac

# --- 1a. The two commands an agent is told to run -----------------------------
# root/CLAUDE.md instructs: bash ~/Developer/_ticketflow/scripts/move-to-verify.sh ...
# Section 1c below refuses any ~/Developer path outside this project, which caught those two from
# 2026-07-31 (d52873f) and broke the ticket workflow in five repos for ten days, silently. The
# allowlist in the board section only skips the board case and never reached 1c. Permit them here,
# anchored to the start of the command and refused if the command carries any chaining or
# substitution, so the exemption cannot smuggle a second command into another project. (BOOT-31)
NORM_EARLY=${CMD//\~\//$HOME/}
NORM_EARLY=${NORM_EARLY//\$HOME\//$HOME/}
BOARD_BIN="$HOME/Developer/_ticketflow/scripts"
# There is no second permitted location. The BOOT-21 grace period allowing
# ~/Developer/_bootstrap/scripts ended on 2026-08-11 when those eight copies were deleted; five had
# drifted, and the move-to-verify.sh among them skipped the criterion check for every ticket that
# existed. A second allowed path is a second answer. (BOOT-60)
# BOOT-114: agent-edit.sh belongs here too. Section 2 below denies a bare `gh issue edit` and its
# message says to use agent-edit.sh, which 1c then refused for naming a path outside the project. The
# guard named a remedy it refused, which is BOOT-70's shape in this same file, and it meant an agent
# could not edit an issue body by ANY route.
#
# That is not merely inconvenient. agent-edit.sh exists so an agent's edit arrives attributed to the
# App rather than to Princess, and move-to-verify.sh baselines a criterion on the newest HUMAN
# revision. With this route shut, the helpful workaround is a human editing on the agent's behalf,
# which silently rebaselines the criterion. The safe failure was the one happening; the unsafe one
# was one step away.
#
# The list has grown one script at a time, each after somebody hit the wall: two at BOOT-31,
# agent-comment.sh later, this one now. It is the whole of _ticketflow/scripts that an agent is told
# to use, and it should stay that way rather than being discovered a fourth time.
# THE FIRST WORD DECIDES, not a prefix of the whole line. The old test required the command to BEGIN
# with `bash ` and vetoed the exemption on any of ; & | ` $ ( > < anywhere in it. Measured
# consequences: the spelling root/CLAUDE.md:43,46,49 publishes was refused; `sh` and a quoted path
# were refused; and a trailing `2>&1 | tail -5` refused a correct call, which is how an agent in
# tiara-site was denied after retrying specifically to satisfy the guard. Piping is how you read a
# script's output. (_bootstrap#134)
#
# ensure-board.sh is added because _ticketflow/README.md publishes it as an entry point other repos
# may hardcode and it has never been in this list. Fourth time this list has been found incomplete.
BOARD_HEAD=$NORM_EARLY
BOARD_HEAD=${BOARD_HEAD#bash }
BOARD_HEAD=${BOARD_HEAD#sh }
BOARD_FIRST=${BOARD_HEAD%% *}
BOARD_FIRST=${BOARD_FIRST//\"/}
BOARD_FIRST=${BOARD_FIRST//\'/}
BOARD_EXEMPT=0
case "$BOARD_FIRST" in
  "$BOARD_BIN/move-to-verify.sh"|"$BOARD_BIN/make-board-ticket.sh"|"$BOARD_BIN/agent-comment.sh"|"$BOARD_BIN/agent-edit.sh"|"$BOARD_BIN/ensure-board.sh")
    BOARD_EXEMPT=1 ;;
esac
# DELIBERATELY NOT `exit 0`. The old exemption skipped sections 1c through 6 entirely: measured, a
# board call could read Config.xcconfig, docs/archive/ and another repo, all of which are denied
# plainly. The flag forgives exactly one thing, at 1c below, and the command remains subject to every
# other rule. A pipe is therefore safe to allow: whatever is on the far side is still judged.

# --- 1c. Cross-project scope guard -------------------------------------------
# If a Bash command targets a path under ~/Developer that is NOT this project,
# the target project's hooks will not fire. Block it so the agent works in the
# project it was launched from.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RESOLVED_PROJECT=$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P)

# NORMALISE FIRST. The original compared only against the expanded path, so a command written
# as `~/Developer/other/...` or `$HOME/Developer/other/...` walked straight past the guard.
# Same class of hole as a check that only greps one directory: the rule was right, its reach
# was not. Found 2026-07-31 while merging this branch.
NORM=${CMD//\~\//$HOME/}
NORM=${NORM//\$HOME\//$HOME/}

# The allow patterns require a boundary after the project path, so a sibling whose name merely
# starts with this project's name (PackMagic vs PackMagicOld) is not silently permitted.
# EVERY ~/Developer path must be this project, not merely one of them. The old test asked "does this
# command mention my project" and allowed the whole command on the strength of a single match, so
# `cp ~/Developer/<this>/x ~/Developer/<other>/y` was permitted: a cross-repo WRITE, allowed because
# the command also named the current project. Found by a session working in _ticketflow. (BOOT-46)
OUTSIDE=$(printf '%s\n' "$NORM" | grep -oE "$HOME/Developer/[A-Za-z0-9_.-]+" 2>/dev/null \
            | sort -u | grep -vxF "$RESOLVED_PROJECT" || true)
# A board call is forgiven its own script directory and nothing else in the same command. The -n
# guard matters: printf '%s\n' "" emits a blank line that grep -vxF would pass through, turning an
# empty OUTSIDE into a non-empty one and denying every board call. (_bootstrap#134)
if [ "${BOARD_EXEMPT:-0}" = 1 ] && [ -n "$OUTSIDE" ]; then
  OUTSIDE=$(printf '%s\n' "$OUTSIDE" | grep -vxF "$HOME/Developer/_ticketflow" || true)
fi
[ -z "$OUTSIDE" ] || deny "command targets $(printf '%s' "$OUTSIDE" | tr '\n' ' '), outside this project. Launch Claude from the target project so its hooks fire." "$CMD"

# BOOT-72: the check above reads $HOME/Developer/<repo> out of the command text, so changing
# directory first deletes the evidence: `cd ~/Developer && cat OtherApp/secret.txt` leaves no
# ~/Developer/<repo> substring to find, and every sibling repo is reachable by a relative path.
# Found by accident, not by looking: an audit agent ran `cd ~/Developer && diff PodaProject/... `
# and was never denied.
#
# Landing IN ~/Developer itself is the whole trick, so refuse that specifically. `cd
# ~/Developer/<this project>` is untouched, and so is any cd inside the project.
case "$NORM" in
  *"cd $HOME/Developer"|*"cd $HOME/Developer "*|*"cd $HOME/Developer;"*|*"cd $HOME/Developer&"*|*"cd $HOME/Developer|"*|*"cd $HOME/Developer/ "*|*"cd $HOME/Developer/")
    deny "changing directory into ~/Developer puts every sibling repo one relative path away, where the cross-project check cannot see it. Work from inside this project." "$CMD" ;;
esac

# --- 2. The board: the agent never owns status -------------------------------
# Status is a judgement about whether work is really done. Forward into Verify is the one
# transition an agent may make, and it goes through move-to-verify.sh, where the target lane is a
# literal. The raw mutation takes opaque option ids, so a hook reading the command cannot tell
# Verify from Done, which is why the raw form is refused outright.
# BOOT-105: THE EXEMPTION IS START-ANCHORED AND VOIDS ITSELF ON ANY SEPARATOR.
#
# This was `*move-to-verify.sh*|*make-board-ticket.sh*) ;;`, unanchored on both sides, so ANY command
# that merely named one of those scripts skipped every denial below it. `gh issue edit 5 --body "see
# move-to-verify.sh"` is the whole exploit: the string sits inside a quoted argument, the exemption
# fires, and the board write goes through.
#
# The sibling exemption at 1a has had both protections since BOOT-31 and this one had neither. Same
# shape as BOOT-46 in section 1c: a test that asks "does this command mention X" and allows the whole
# command on the strength of one match.
#
# A legitimate board call does not depend on this branch. It is start-anchored at 1a and exits there,
# or it dies at 1c for naming a path outside the project. What reaches here is a command that mentions
# the name without being the call, so BOARD_CALL is almost always 0. The branch is kept rather than
# deleted because "almost always" is not "always", and a deleted exemption is a refusal nobody
# predicted.
BOARD_CALL=0
case "$NORM_EARLY" in
  *[\;\&\|\`\$\(\>\<]*) ;;
  "bash $BOARD_BIN/move-to-verify.sh "*|"bash $BOARD_BIN/make-board-ticket.sh "*) BOARD_CALL=1 ;;
esac
[ "$BOARD_CALL" = 1 ] || case "$CMD_FLAT" in
  *updateProjectV2ItemFieldValue*|*"gh project item-edit"*)
    deny "the agent does not set board fields directly. Forward into Verify is the only move you may make, and it goes through: bash ~/Developer/_ticketflow/scripts/move-to-verify.sh <repo> <projectNumber> <issueNumber>. Never to Done, never backwards, never Priority or Type. Ask the human for anything else." "$CMD" ;;
  *"gh issue create"*)
    deny "create tickets through make-board-ticket.sh so they land on the board with a Lane, and give the link. A bare 'gh issue create' makes an issue no board can see." "$CMD" ;;
  *"gh issue comment"*)
    deny "comment through agent-comment.sh, so your writing is visibly an agent's and not Princess's. A bare 'gh issue comment' posts as her." "$CMD" ;;
  *"gh issue edit"*)
    deny "edit a body through agent-edit.sh, which writes as the App and refuses to touch an Acceptance section. A bare 'gh issue edit' writes as Princess, and the criterion gate would then treat your edit as her baseline." "$CMD" ;;
  # BOOT-104: closing a ticket IS Done, and Done is a human's judgement. Tiara maps any closed issue
  # to done whatever its Lane says, so `gh issue close` reaches the state the whole of section 2
  # exists to keep out of an agent's hands, by the one route that was never listed.
  *"gh issue close"*)
    deny "closing a ticket is Done, and Done is a human's judgement. Tiara renders any closed issue as done whatever its Lane says. Forward into Verify is the only move you may make: bash ~/Developer/_ticketflow/scripts/move-to-verify.sh <repo> <projectNumber> <issueNumber>. Ask the human to close it." "$CMD" ;;
  # And a transfer is a larger board mutation than a close, which is why FD-0016 names it a human
  # act. It moves the issue off its board entirely, and whether it lands on the destination board
  # depends on the auto-add BOOT-30 records as configured by hand and verified by nobody. It also
  # changes the issue number, so every commit and ticket already citing it points elsewhere.
  *"gh issue transfer"*)
    deny "moving a ticket between repos is a human act (FD-0016). A transfer takes the issue off its board, and changes its number so every existing citation of it breaks. If the work belongs in another repo, ask the human to transfer it and to check it landed on that repo's board." "$CMD" ;;
esac

# The same endpoints, reached a different way. `gh issue create` was refused and `gh api ... /issues`
# was not, which is the same rule expressed as a literal instead of as a decision about an action.
# Only WRITES are refused: reading an issue with gh api is legitimate and common. (BOOT-54)
case "$CMD" in
  *"gh api"*/issues*)
    case "$CMD" in
      *"-X POST"*|*"-X PATCH"*|*"-X DELETE"*|*"-X PUT"*|*"--method POST"*|*"--method PATCH"*|*"--method DELETE"*|*" -f "*|*"--field"*|*"--input"*)
        deny "this writes to the issues API directly, which skips every check make-board-ticket.sh, agent-comment.sh and agent-edit.sh perform. Reading with gh api is fine; writing is not." "$CMD" ;;
    esac ;;
esac

# A GraphQL mutation supplied from a file or stdin never puts its own name in the command text, so no
# string matcher can see it, in a hook or in a deny rule. Two of the board scripts already do this.
# Refusing the delivery mechanism is the only thing that catches the class. (BOOT-54)
case "$CMD" in
  *"gh api"*graphql*)
    case "$CMD" in
      *--input*|*"query=@"*|*--stdin*)
        deny "a GraphQL mutation supplied from a file or stdin is invisible to this guard, so it is refused outright. Board changes go through the scripts." "$CMD" ;;
    esac ;;
esac



# --- 1d. The archive is not readable -----------------------------------------
# FD-0011: an archived document is finished. Reading one as current is how a closed finding gets
# reopened. settings.json denies the Edit/Read/Write TOOL route. A deny rule of the form Bash(...)
# DOES bind shell commands, is harness-evaluated independently of this hook, and survives this hook
# being disabled, measured in _bootstrap#148. An earlier comment here said the opposite. That belief
# is why irreversible-act rules were written as patterns in this file instead of as deny rules.
#
# DENY BY DEFAULT, allowlist the archiving operations. The previous version did the opposite: it
# matched `docs/archive/` anywhere and refused everything, including an agent MOVING a finished
# document in, which is what the rules tell it to do. It was removed for that in BOOT-31 and the
# route stayed open.
#
# Deny-by-default rather than a list of read verbs, because enumerating the bad case is what lost
# repeatedly in Wave 1: `/./` defeated every rule in guard-scope, quoting defeated the override
# token, a `cd` defeated the cross-project check, and a verb list missed sed -i, perl -pi and cp.
# There are three ways to put a document into the archive and unbounded ways to read one, so the
# short list is the permitted one.
#
# HONEST LIMIT, stated rather than implied: this reads the command text, so the bypass classes
# compliance.mjs already records as open (python3 -c, variable splicing, curl | sh) are open here
# too. It stops the agent that reaches for `cat`, which is the realistic case, not the determined
# one. (BOOT-83)
case "$NORM" in
  *docs/archive*)
    case "$NORM" in
      # A shell separator voids the exemption. Anchoring the allowlist at the start of the command is
      # not enough on its own: `git add docs/archive/x && cat docs/archive/x` starts with a permitted
      # verb and smuggles a read in after it. Measured, and it got past the first version of this
      # block. Same guard the board-command exemption already uses two sections down.
      *[\;\&\|\`\$\(\>\<]*)
        deny "docs/archive/ is not readable, and a command combining several operations cannot be exempted. Run the archiving step on its own: git mv <path> docs/archive/ (FD-0011)." "$CMD" ;;
      # Putting a finished document IN, and the bookkeeping around it.
      "git mv "*|"git add "*|"git rm "*|"git status"*|"git commit "*|"mkdir "*|"mkdir -p "*|"mv "*) ;;
      *) deny "docs/archive/ holds finished documents and is not readable. They were true when written and describe work that is already closed, so reading one as current is how a closed finding gets reopened. If you need what it knew, ask the human or read the ticket. You may still move a document IN: git mv <path> docs/archive/ (FD-0011)." "$CMD" ;;
    esac ;;
esac

# --- 2. Secrets --------------------------------------------------------------
# The agent must never read the API keys, not even to "check" them.
# It only takes one transcript.
case "$CMD" in
  *Config.xcconfig*)     deny "Config.xcconfig contains API keys" "$CMD" ;;
  # BOOT-74: `*".env"*` matched anywhere in the command, and `.environment` and
  # `.environmentObject` are ordinary SwiftUI, so `grep -rn ".environment" Sources` was refused with
  # "env files contain secrets", which is not what the agent was doing. A guard that refuses ordinary
  # work is the failure mode this layer has already had once, and the agent's rational response to a
  # nonsense refusal is to look for a way around it. Match the FILENAME, not the substring.
  *".env "*|*".env"|*"/.env"*|*".env."*|*".envrc"*|*".env_"*|*".env-"*)
                         deny "env files contain secrets" "$CMD" ;;
  *"security find-"*)    deny "keychain access" "$CMD" ;;
esac


# --- 3. Production data ------------------------------------------------------
# Debug builds talk to the development CloudKit container. Always.
# A single production write from a dev machine is not recoverable.
case "$CMD" in
  *"iCloud.com."*"production"*)          deny "production CloudKit container" "$CMD" ;;
  *"cktool"*"--environment production"*) deny "cktool against production" "$CMD" ;;
esac

# --- 4. Project file ---------------------------------------------------------
# See FD-0001. The project is generated by XcodeGen from project.yml, so the agent
# never has a legitimate reason to touch the project file.
case "$CMD" in
  *".pbxproj"*)          deny "project file is managed by Xcode, not the agent" "$CMD" ;;
esac
# CMD_FLAT and mutating_verb() are defined at the top, so every rule can use them (BOOT-92).
case "$CMD_FLAT" in
  *allow-changed-override*|*allow-claude-md-edit*)
    deny "the human-only override token cannot be issued by an agent, however it is spelled. Ask the human to run it." "$CMD" ;;
esac
# BOOT-92: five spellings were enumerated here and cp, mv, install and every interpreter walked
# straight past. Matched on `.claude` WITHOUT a trailing slash, so `C=.claude; cp x $C/token` is
# caught too. Path splitting still defeats this and always will; see the ticket.
case "$CMD_FLAT" in
  *".claude"*)
    mutating_verb && deny "creating or writing a file under .claude/ is a human action, by any command. The enforcement layer is not writable by the thing it judges (R6)." "$CMD"
    case "$CMD_FLAT" in
      *"> .claude/"*|*">.claude/"*|*">> .claude/"*)
        deny "writing into .claude/ from the shell is a human action (R6)." "$CMD" ;;
    esac ;;
esac

# --- 5. The human-only override token ----------------------------------------
# `.claude/allow-changed-override` is the one-shot authorisation that lets a finish block
# waive the CHANGED-versus-diff check. Only a human may create it, because CHANGED is the
# record of what the agent did and must not be waivable by the agent itself.
#
# settings.json denies Write/Edit on that path. This blocks the shell route as well: one
# layer is a typo away from none (FD-0001's own reasoning).
case "$CMD_FLAT" in
  *allow-claude-md-edit*)
    deny "the CLAUDE.md edit token is human-only. Say what you would change and why, and ask the human to run: touch .claude/allow-claude-md-edit" "$CMD" ;;
  *"> CLAUDE.md"*|*">CLAUDE.md"*|*">> CLAUDE.md"*|*"tee CLAUDE.md"*|*"tee -a CLAUDE.md"*)
    deny "CLAUDE.md loads on every turn. Do not write it from the shell. Propose the change and why, and let the human decide." "$CMD" ;;
  *allow-changed-override*)
    deny "the CHANGED-override token is human-only. Ask the human to run: touch .claude/allow-changed-override" "$CMD" ;;
esac

# BOOT-73: the locks above and in section 6 match only >, >> and tee. Seven other ordinary ways to
# write a file walked straight past: sed -i, perl -pi, cp, mv, patch, python3 -c, and an ex script.
# Measured, all rc=0, against both CLAUDE.md and the vendored FD set.
#
# Matched on the quote-stripped copy and on the mutating VERB rather than on the redirect, since
# enumerating redirect spellings is what left the hole. Deliberately conservative: `cp CLAUDE.md
# /tmp/backup` is a read and this refuses it too. A refused read costs a sentence; a permitted write
# to an always-loaded file costs every future session.
case "$CMD_FLAT" in
  *CLAUDE.md*|*"docs/decisions/factory"*)
    mutating_verb && deny "CLAUDE.md and the vendored factory decisions are not writable from the shell, by any command. CLAUDE.md loads on every turn and an FD- is authored only in _bootstrap. Say what you would change and why, and let the human decide." "$CMD" ;;
esac

# --- 6. The decision log is agent-read-only, except proposed/ ----------------
# FD- decisions are authored only in _bootstrap and vendored, read-only, into every repo.
# AD- decisions are authored by a human from a proposal. The only agent-writable spot is
# docs/decisions/proposed/. This blocks the shell write route into the vendored factory set;
# settings.json blocks the Edit/Write tool route. Reads are fine, only write-redirects blocked.
case "$CMD_FLAT" in
  *"> docs/decisions/factory/"*|*">docs/decisions/factory/"*|*">> docs/decisions/factory/"*|*"tee docs/decisions/factory/"*|*"tee -a docs/decisions/factory/"*)
    deny "the decision log is read-only to agents. An FD- is authored ONLY in _bootstrap and approved by a human. Do not create it here; put a proposal in docs/decisions/proposed/ and ask the human (FD-0000)." "$CMD" ;;
esac

# _bootstrap#118: BOOT-113 closed the authoring half. This is the propagation half. Both scripts
# rewrite what every repo receives: factory-lock.sh re-locks .factory-checksum, which every repo's
# conform compares its vendored FD set against, and fd-block.sh --write regenerates the CLAUDE.md
# block that loads on every turn everywhere. fd-block.sh:23 already says a human runs --write,
# through vendor-factory.sh. This makes that sentence true rather than aspirational.
case "$CMD_FLAT" in
  "bash "*factory-lock.sh*|*" bash "*factory-lock.sh*|"sh "*factory-lock.sh*|*" sh "*factory-lock.sh*|*"./"*factory-lock.sh*|"scripts/factory-lock.sh"*)
    deny "re-locking the factory checksum is a human action. It certifies the decision set every repo compares against, so an agent that could run it could certify content it had just authored (_bootstrap#118)." "$CMD" ;;
esac
case "$CMD_FLAT" in
  "bash "*fd-block.sh*|*" bash "*fd-block.sh*|"sh "*fd-block.sh*|*" sh "*fd-block.sh*|*"./"*fd-block.sh*|"scripts/fd-block.sh"*)
    case "$CMD_FLAT" in
      *--write*)
        deny "fd-block.sh --write regenerates the CLAUDE.md block that reaches every repo. A human runs it, through vendor-factory.sh, which fd-block.sh:23 already states. --check is open to you (_bootstrap#118)." "$CMD" ;;
    esac ;;
esac
# docs/decisions/proposed/ is the ONE place an agent may write, which makes it the one place an
# agent may destroy. A proposal a human approved is the record of what they approved: BOOT-113's
# step 2 deleted a 356 line approved proposal and nothing refused it.
case "$CMD_FLAT" in
  *"docs/decisions/proposed"*)
    case "$CMD_FLAT" in
      "rm "*|*" rm "*|*"rm -"*)
        deny "deleting a decision proposal is a human action. Proposed/ is the one place you may write, which makes it the one place you may destroy. Say which file should go and why, and let the human remove it (_bootstrap#118)." "$CMD" ;;
    esac ;;
esac
exit 0
