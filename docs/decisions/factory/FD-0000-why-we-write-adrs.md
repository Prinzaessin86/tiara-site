# FD-0000. Why we write ADRs, the FD-/AD- numbering system, the structure, and the ADR-vs-SPEC boundary

**Status:** Accepted
**Date:** 2026-08-01
**Enforced by:** scripts/check-adrs.sh enforces the hygiene half (filename id, title id, required fields, allowed statuses, symmetric supersession) and make conform verifies the vendored checksum. The namespace split, the deviation rule, and the ADR-vs-SPEC boundary are human discipline; a script cannot tell a factory decision from an app one.

## Context

A decision that lives only in a chat, or as a one-line row in a register, evaporates. The
reasoning is gone by the next session and the decision gets re-litigated from scratch. The
factory's whole thesis is that a rule with no durable, checkable home drifts. ADRs are that
home for decisions, the way the compliance board is the home for facts.

## Decision

Every meaningful decision gets a numbered file in `docs/decisions/`, with Context, Decision and
Consequences, and the required fields **Status**, **Date** and **Enforced by**.

Two namespaces, by prefix:

- **FD-** is a factory decision, authored only in `_bootstrap` and vendored, read-only, into every
  repo. FD- numbers are shared and stable: FD-0006 means the same thing in every repo, forever,
  which is what lets it be quoted out of context without ambiguity.
- **AD-** is an app decision, local to one app.
- `_bootstrap` holds both FD- and AD-. Every other repo holds only AD- plus the vendored FD- set.

Numbering:

- FD- numbering starts at FD-0000, this decision. AD- numbering starts at AD-0001, because this
  meta-anchor is shared via FD-0000 and is not repeated per app.
- Numbers are permanent and never reused. Gaps stay gaps, from FD-0010 forward.

Deviation and promotion:

- An app deviates from an FD- only by writing an AD- that says "Deviation from FD-000n" with the
  reason. Silent deviation is the failure; a declared deviation is fine.
- A decision that proves universal is promoted to a new FD-, and the app's AD- becomes
  `Superseded by FD-00nn`.

Supersession and correction:

- A reversal is a supersede with pointers both ways (`Supersedes` and `Superseded-by`), and may
  cross namespaces (an AD- may be superseded by an FD-).
- A correction of a record that drifted from practice is amended in place with a dated note, the
  original text retained.

## Structure

```
docs/decisions/
  README.md            a generated index of both namespaces; never hand-edited
  factory/             the vendored FD- set: read-only and agent-denied
    .factory-checksum  the hash make conform verifies, so a local edit fails the gate
    FD-0000-....md ...  the factory decisions, identical in every repo
  AD-0001-....md       this app's own decisions, at the root
  proposed/            the only agent-writable location; a human moves a proposal to Accepted
```

The FD- set is vendored (copied), not linked, because Claude Code scopes to the project directory
and cannot read a shared file outside it. The set is versioned by the top-level FACTORY_VERSION,
and the board's factory_current check flags a repo that is behind; `factory/` carries only the checksum. Binding: settings.json denies Edit/Write on
`docs/decisions/` except `proposed/`, guard-bash.sh blocks shell writes to the same path, and make
conform verifies the factory checksum and that every supersession is symmetric.

## The ADR-vs-SPEC boundary

- An ADR records an engineering or architecture decision with a tradeoff.
- Product philosophy and "what the app is" belong in `SPEC.md`, not in an ADR.
- When an existing ADR is really product philosophy, it moves to SPEC only after its claim is
  verified against the code, never copied blind.

An ADR is not a procedure. A decision is stable and says why; a procedure is a sequence of
steps and says how. The two have different homes and different audiences. The factory-wide
"how we build" procedures live once, in the Tiara Runbook: the stages every app climbs, and
the recipes for building a queue item, standing up a new app, shipping to TestFlight, and
modernizing. Those are for a human, with runnable commands. An agent-invocable procedure that
is specific to one app lives in that app's `.claude/skills/`, loaded on demand. There is no
`docs/runbooks/` directory in this factory and there never was.

## Consequences

`scripts/check-adrs.sh` is the executable half of this ADR and fails closed. What it cannot see,
the namespace split, whether a deviation was declared, whether something is really SPEC, stays
human discipline. Only a human moves a proposal to Accepted.
