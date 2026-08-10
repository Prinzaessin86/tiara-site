# FD-0012. Every product separates DEV from PROD before it has features

**Status:** Accepted
**Date:** 2026-08-02
**Enforced by:** compliance bundle_split, dev_scheme and prod_scheme. The DEV-build visual
distinctness and the DEV-only seed data clauses have no automated check yet and are human
discipline until one exists.

## Context

This rule has been in force since before the factory existed, as prose in the global working rules,
marked NON-NEGOTIABLE. Prose is why it drifted. It was written assuming every app uses CloudKit, so
PackMagic, which is deliberately local-only with no CloudKit at all, could never satisfy a rule
marked non-negotiable, and nothing ever noticed. A rule no app can fail and one app cannot pass are
the same failure: nobody is checking.

It also sat in the wrong layer. The global working rules describe how the agent behaves. This
describes how a product is built, which makes it a factory decision, and factory decisions carry a
status, a date, an enforcement mechanism, and a place a deviation can be declared.

## Decision

Every product separates DEV from PROD from the first commit, before any feature work.

- **Distinct bundle identifiers.** The shippable app and the dev variant are different apps on the
  device, never one app with a flag. Naming follows FD-0006.
- **The DEV build is unmistakable at a glance:** its own display name and a visually distinct icon
  or accent. A screenshot must never be ambiguous about which build produced it.
- **Seed and test data are DEV-only** and cannot compile into a Release build.
- **An app that uses CloudKit uses separate containers**, and dev and prod data never share one.
  An app with no cloud has nothing to separate at this level and is compliant by construction.
- **Set it up first.** Retrofitting environment separation onto an app that already has data is
  where the expensive mistakes live.

Where an app needs stronger isolation than bundle identity gives, it says so in its own AD-, as
PodaProject did with container-level separation in AD-0004.

## Consequences

The rule now has an enforcement mechanism rather than an adjective. PackMagic passes rather than
being permanently and invisibly non-compliant. The CloudKit clause is conditional, which is what it
always meant. And the global working rules lose a product rule they were never the right home for,
which is the point of the FD and AD split in FD-0000.
