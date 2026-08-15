# FD-0014. An agent does not push. Verify tells a human when to.

**Status:** Accepted
**Date:** 2026-08-12
**Enforced by:** guard-bash.sh refusing every agent push to a landing branch, unconditionally; and a
conform check that each repo's `verify` target calls the advice script.

## Context

The factory has had a rule that an agent may push to `main` only when `make verify` has passed on
exactly the code being pushed. The mechanism was a leash: `make verify` would record a fingerprint of
the tree into `.verify-pass`, and `guard-bash.sh` would allow the push only when that file matched
the tree.

Half of that mechanism was never built. No `Makefile` in any repo has ever written `.verify-pass`.
The file has never existed. So the comparison has always been against nothing, the leash has refused
every agent push since the day it shipped, and every push in the estate's history has been a human
running the command outside hooks.

The failure is instructive rather than embarrassing. Nobody noticed for weeks because the block looked
like correct behaviour: an agent hitting it reads a message saying to run `make verify` and push,
does so, is refused again, and concludes the code is at fault. The guard even names a remedy that
cannot work. A gate that is unsatisfiable is worse than a gate that is absent, because it is
credited: the estate believed pushes were verify-gated when nothing was.

Repairing the leash is a two line change. It was rejected deliberately. Writing `.verify-pass` would
hand every agent the ability to push to `main` on its own judgement, and a conditional block that an
agent can satisfy by running a command is not a leash. It is a capability with a checklist.

The deeper observation is that the leash was never the real control. A human bypasses hooks by
construction, so the guard only ever governed agents, and the guarantee it appeared to offer, that
what reaches `main` has passed `verify`, was never enforced against the person who actually pushes.

## Decision

**An agent does not push. `make verify` reports whether the work is ready to land, and the human
lands it.**

Three parts:

1. **The block is unconditional.** `guard-bash.sh` refuses an agent's push to a landing branch with
   no test, no fingerprint and no file to satisfy. It refuses because that is the rule, not because a
   condition failed. The `.verify-pass` comparison is deleted rather than repaired.

   **The marker itself survives, at `.claude/.verify-pass`.** This clause originally said nothing
   anywhere writes that file, which was wrong and was corrected on 2026-08-15 by BOOT-115. The file
   had two readers and this decision knew one. `compliance.mjs`'s `gate_green` uses it as its only
   evidence that a repo's gate has passed on the code as it stands, and deleting the writer would
   have reported false in every repo, which is indistinguishable from a gate that has never run.

   What this decision removes is the file's authority, not the file. At the repo root, read by a
   guard before a push, it decided whether an agent could publish. Under `.claude/`, beside
   `.turn-start` and `gate.log`, it is what it always was underneath: state the gate writes about
   itself. Nothing is authorised by it.

2. **`verify` ends by reporting, when there is something to report.** On success, and only when the
   branch is ahead of its remote, it names how many commits are ready and prints the exact command
   for the human to run. It refuses to call a dirty tree ready, because a push sends commits and not
   the working tree, so a green verify on uncommitted work describes something other than what would
   land. When nothing is ahead it says nothing, because advice nobody needs is noise, and noise in a
   command that runs every turn is how a gate stops being read.

3. **The report is a derived fact, not a claim.** It comes from `verify` itself, reading the
   repository. An agent asserting in prose that the tests passed is worth nothing; the same sentence
   printed by the thing that ran them is worth something. This is the same principle as a lane gate
   deriving its evidence instead of accepting a pointer.

## Consequences

**Stated plainly, because this trade is the whole decision: nothing verifies what reaches `main`.**
Agents cannot push at all, and the human's push goes around hooks, so no automated check stands
between a red tree and the remote. The advisory line is advice. Anyone may ignore it.

That is not a regression. It is the honest description of a state the estate was already in, since
the leash never once held. What changes is that it is now true on purpose, legible in one ADR,
rather than true by accident and believed to be otherwise.

If enforcement against the human is wanted later, this decision is the wrong place for it and a
pre-push hook is the right one. That is a separate decision and should be argued separately.

**The guard's refusal must name the real path.** Its current message tells the reader to run
`make verify` because it records a pass. Under this decision nothing records a pass, so that sentence
would send every future reader hunting a bug that no longer exists. It is replaced by one that says
an agent does not land work here and that `verify` will say when it is ready.

**One implementation, not one per repo.** The report lives in a vendored script that each `Makefile`
calls as the last line of `verify`. The repos have materially different verify targets, so inlining
it would produce seven drifting copies of the same paragraph.

**One comment in `scripts/tree-fingerprint.sh` becomes false and must go in the same pass**: that a
later push can compare the recorded fingerprint to prove the code has not moved. That is the leash,
and it is what this decision removes.

Its other two claims survive, and this paragraph originally said they did not. Corrected on
2026-08-15 by BOOT-115. `make verify` does record the fingerprint it passed on, at
`.claude/.verify-pass`, because `gate_green` needs it. And the marker IS excluded from the
fingerprint by `.gitignore`, which was the half that had never been true: the entry was absent from
every `.gitignore` in the estate when this was written, so the marker would have invalidated itself
on write had anything ever written it. Both `.gitignore`s now carry it, and the old repo-root path
too for as long as `compliance.mjs` still falls back to reading it.

## Alternatives considered

**Repair the leash.** Write `.verify-pass` from `verify`, add it to `.gitignore`, and let a verified
agent push. This is the smaller change and it is the only version where the gate gates anything.
Rejected because it grants an outward-facing capability to agents in exchange for a guarantee that
still would not bind the human.

**Leave it broken.** Costs nothing today, since the human pushes anyway. Rejected because the estate
would go on believing pushes are gated, and the next person to read the guard would spend the same
hours working out that the remedy it names cannot work.
