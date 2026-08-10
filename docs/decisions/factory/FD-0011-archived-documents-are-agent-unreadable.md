# FD-0011. Finished documents are not maintained, and agents do not read them

**Status:** Accepted
**Date:** 2026-08-02
**Enforced by:** settings.json deny, guard-bash, guard-scope, conform archive_blocked_in_both_layers

## Context

A finished document is not a false document. A dated audit, a completed project plan, a superseded
brief: each was true when written, and each stops being true the moment the code moves on. Deleting
them loses a record that git holds anyway; leaving them in `docs/` invites an agent to read them as
current and act on findings that were closed weeks ago.

The factory already learned the cost of the second failure. A CLAUDE.md that accumulated build logs
and dated audits reached 128 KB in one repo, and the material was being loaded on every turn to
describe work that was already done.

There is history here. D44, on 2026-07-31, removed the deny rules that hid `scramble.md` from
agents, on the grounds that they guarded six files of untouched boilerplate and so protected
nothing. That reasoning was right for that content. It does not extend to documents with real
findings in them, which is what this decision covers.

## Decision

`docs/archive/` is the one place a finished document may live on disk, and its contents are
unreadable and unwritable to agents. It is blocked in both layers, never one: `settings.json` denies
the Read, Edit and Write tool routes, and `guard-bash` denies the shell route with a message that
says why. A document moved there keeps its filename and its dates; nothing about it is rewritten,
because rewriting a dated record to satisfy a link checker makes it claim knowledge it did not have.

A live document that cites an archived one loses the citation in the same commit that archives it.
A dangling pointer to a blocked file is worse than no pointer: the next session assumes it was read.

This is where a finished document goes. It is not where knowledge goes. Knowledge belongs in
`.claude/rules/` beside the code it describes, and a procedure belongs in `.claude/skills/` if it
is for an agent, or in the Tiara Runbook if it is a factory-wide recipe for a human.

## Consequences

An agent that opens an archived document is stopped and told the document is finished, rather than
silently reading it and treating a closed finding as open. The record stays on disk and stays
openable by a human, so archiving costs nothing that deleting would have saved.

The block covers the Read tool and the shell. It does not make a file unreadable in an absolute
sense, and it is not a security control: no secret belongs in `docs/archive/` any more than it
belongs anywhere else in the repo.
