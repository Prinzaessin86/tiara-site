# FD-0010. CI (build and test) runs on Xcode Cloud, not GitHub Actions

**Status:** Accepted
**Date:** 2026-08-01
**Enforced by:** compliance ci_workflow, not_tangled and last_build_green; conform fails on a
GitHub Actions workflow that builds or tests
**Amended:** 2026-08-02. Originally kept the GitHub Actions `verify` workflow as a manual
break-glass fallback, and left the cloud test lane to a manual trigger. Actions is now removed
entirely, and a version bump is the single trigger for every cloud lane.

## Context

Continuous build and test has to run somewhere. Both GitHub Actions and Xcode Cloud are available.
The factory already releases to TestFlight on Xcode Cloud (FD-0005), so running CI on the same
platform keeps one signing path, one toolchain, and one place to read a failure. This decision was
made twice in the field before it was a factory rule, in Bubbles and in rainybow, which is exactly
the signal that it should be promoted rather than re-decided per app.

## Decision

Continuous integration, build plus test, runs on Xcode Cloud and nowhere else. **GitHub Actions is
not used to build or test any app.** There is no break-glass fallback, because the fallback was a
second way to do the same thing on a runner that bills at ten times the rate.

**A version bump is the trigger for everything that runs in the cloud.** One deliberate act, one
place, and every cloud lane follows from it. A manual trigger nobody remembers to run is not a lane,
it is an intention.

| Lane | Runs when | Applies to |
|---|---|---|
| `make verify`, local | every change | every repo |
| Xcode Cloud test | a build-number bump in `Config/Version.xcconfig` on `main` | every app |
| Xcode Cloud archive to TestFlight | the same bump | apps that ship, marked by `release.yml` |

**Bump after a major change, not after every commit.** A version bump says this is a checkpoint
worth spending cloud minutes and a tester's attention on: a feature landed, a release is intended,
a refactor finished. Ordinary commits do not bump, which is what keeps the quota finite and the
trigger meaningful. The per-change gate is `make verify` and it is free.

An app on TestFlight gets both lanes from the one bump: CI proves it builds and tests green, the
archive puts it in front of testers. An app not yet shipping gets the test lane only, and gains the
archive lane the day it opts in with `release.yml`.

Both Xcode Cloud workflows therefore carry the same start condition: Branch Changes on `main`,
filtered to `Config/Version.xcconfig`. `scripts/xcc.js` still exists for an out-of-band run, but it
is not the path anything depends on.

An app that needs a different trigger declares it in its own `AD-`.

## Consequences

There is one CI platform, aligned with release, and one answer to "where does this run". A green
Actions run can no longer be mistaken for the gate, because there is no Actions run. And there is
one trigger to understand rather than three: bump the version and the cloud does the rest. The four
leftover workflows are deleted: `ci.yml` in Bubbles, PackMagic and PodaKnows, and `build.yml` in
Dailylog. The template already ships no `.github/` directory, so no new app inherits one. The
board's `ci_workflow` check reads the App Store Connect API rather than GitHub, so nothing on the
board changes.

One thing this makes visible rather than causes: those workflows were the only place `make coverage`
and `gate-canary.sh` were wired to run automatically, and being manual-dispatch they never did.
After this, no automated runner measures coverage anywhere. That is the honest state, and it is the
subject of separate work rather than a reason to keep a workflow that pretends.

Promoted to the factory from Bubbles 0011 and rainybow 0012, the first two promotion candidates
under FD-0000.
