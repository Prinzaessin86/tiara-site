# FD-0004. Time and randomness are injected, not read from a global

**Status:** Accepted
**Date:** 2026-07-22
**Enforced by:** advisory: no automated check yet (a PostToolUse Date()-outside-composition-root grep is planned)

## Context

A test that reads the wall clock or the system random source is not a test, it is a coin
flip that usually lands the same way. It passes a hundred times, then fails once in CI at
2am when the date rolls over a boundary or a shuffle happens to produce the unlucky order,
and no one can reproduce it. A real bug of exactly this shape has already shipped in this
family of apps: an engine that called the global random source produced different output
every run, so its behaviour could never be pinned down or regression tested.

Higher testing disciplines make this worse, not better. Snapshot tests compare a rendered
buffer: if the view shows "2 minutes ago" computed from `Date()`, the snapshot is
different every run. Property tests need a seed to shrink a failing case. Neither works on
top of hidden global state.

## Decision

1. **Time is a value you pass in.** `Sources/Support/Now.swift` wraps "what time is it".
   Production builds `Now.live` once in the composition root and passes it down. Nothing
   else calls `Date()`. Tests and previews use `Now.fixed(...)`.
2. **Randomness is a parameter.** Engines accept a `RandomNumberGenerator`. Production
   passes `SystemRandomNumberGenerator()`. Tests pass `SeededRandomNumberGenerator(seed:)`
   (`Sources/Support`), which is a deterministic PRNG: same seed, same sequence, every run.
   Nothing calls `Int.random(in:)` or `Array.shuffle()` on the global source inside an
   engine.
3. **The seams are proven, not assumed.** `Tests/SupportTests.swift` asserts the seeded
   RNG replays identically and the fixed clock does not move. If that suite is ever red,
   every downstream test that relies on reproducibility is untrustworthy, so it is treated
   as load bearing and is not deleted.

## Consequences

Easy: every test that touches time or chance is reproducible, which is the precondition
for snapshot, property, and engine tests to exist at all. Date-boundary and shuffle bugs
become writable as ordinary failing tests instead of unreproducible ghosts.

Hard: engines take one or two more init parameters. That is a small, one time cost paid at
the composition root, and it is the same discipline as dependency injection everywhere
else. The rule is simple enough to enforce by eye in review: if a value depends on the
time or on chance, its source is a parameter, not a global.

Note: this ADR exists because the bug was made (an unseeded engine), not avoided.
