# FD-0016. A ticket lives in the repo its work lands in

**Status:** Accepted
**Date:** 2026-08-15
**Enforced by:** the rule itself needs no check: `move-to-verify.sh` searches the ticket's own repo
and nowhere else, so a ticket in the wrong repo already refuses. What is NOT yet enforced is the
declared exception, the `Global` and `Repos` fields, which nothing reads until
`_ticketflow#31` lands. Stated here rather than named as a check that does not exist.

## Context

The deliverable gate looks for commits in the repository the ticket lives in. Work done elsewhere is
invisible to it, so a `code` ticket whose commits landed in another repo can never be moved.

Three tickets hit this on 2026-08-11, immediately after the ticket workflow moved out of
`_bootstrap`: BOOT-42, BOOT-47 and BOOT-48. All three were complete, cited their ticket correctly and
were pushed. Their commits were in `_ticketflow`; the gate looked in `_bootstrap`.

The obvious repair, letting the gate search a configured set of repos, is worse than it looks.
`cite_regex` accepts a bare `#<n>`, which carries no repository, so widening the search widens what
can satisfy it: a stray `fixes #42` in any searched repo would finish `_bootstrap`'s ticket 42. A
gate that passes wrongly is worse than one that refuses wrongly.

BOOT-45 closed on 2026-08-11 and `_ticketflow` has board 14. Fifteen boards now exist, so every repo
that receives work can hold its own tickets. That was not true when the problem was filed.

## Decision

**A ticket is filed in the repo its work will land in.** `_ticketflow` tickets go on board 14,
`_bootstrap` tickets on board 13, an app's tickets on its own board.

**Where work genuinely spans repos and no single repo is its home, the ticket says so and then owes
its deliverable in each repo it names.** Two optional fields carry that, and neither is a
`Deliverable` option, because the span is a separate fact about the work rather than a kind of
deliverable:

```
### Global      no: this work lands in one repo   |   yes: this work spans several repos
### Repos       the repos it spans, chosen from the registry
```

What "owes its deliverable in each" means depends on the kind, which is why `Global` is its own
field:

| Deliverable | Per repo, when `Global` is yes |
|---|---|
| `code` | a commit citing the ticket in that repo |
| `document` | the named file committed in that repo |
| `decision` | the named proposal or ADR committed in that repo |
| `investigation` | nothing. The answer is a comment on the ticket, which has no repo |
| `manual` | nothing. It never blocks |

**Declaring repos narrows, it does not widen.** A ticket claiming two repos has set itself a harder
bar than a single-repo one, and a stray commit in a third repo helps it not at all. Everywhere else
in this factory claiming more scope buys leniency; here it buys obligation.

**A misfiled ticket is moved by a human.** `gh issue transfer` changes the issue number, so every
existing citation of it breaks, and it does not place the issue on the destination board. An agent
may not run it.

## Consequences

Every repo that receives work needs a board. Fifteen exist; that becomes a standing requirement
rather than a convenience.

A ticket about the ticket workflow is a `_ticketflow` ticket, even though the rule it changes is a
factory rule. The `FD-` ADR still lives here. Those are different artefacts and only the ticket
moves.

The refusal must say where it looked and why that was the wrong place. Searching the whole registry
to EXPLAIN a refusal is safe, because nothing about the decision changes; only searching to
AUTHORISE is not.
