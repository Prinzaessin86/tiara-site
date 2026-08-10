# FD-0006. Scheme and app naming: the shippable thing is `<App>`, the dev variant is `<App> DEV`

**Status:** Accepted
**Date:** 2026-07-22
**Enforced by:** compliance dev_scheme and prod_scheme

## Context

Every app is built in two flavours from one project: a DEV variant (local, on-device
testing, seed data, a distinct bundle id so it installs beside the real app) and a PROD
variant (what actually ships). Xcode Cloud and every human read the flavour off the
**scheme name**, so the names must say, at a glance, which is which. An earlier convention
named the dev/test scheme `<App>` and the release scheme `<App> Prod`, which is backwards:
it made the *dev* build look like the real product and buried "this is the one that ships"
behind a suffix. It also caused a real mistake, an Xcode Cloud workflow picking `<App> Prod`
(the archive scheme, which has no test targets) for a CI test run.

## Decision

**The shippable product is named plainly; the dev variant carries the `DEV` label. Always.**

- **`<App>`** is the **PROD** scheme. Release config, real bundle id (`com.…​.app`), the real
  `AppIcon`, display name `<App>`, `archive` action. App target only. Xcode Cloud **release**
  workflows use this scheme.
- **`<App> DEV`** is the **DEV / test** scheme. Debug config, `.dev` bundle id
  (`com.…​.app.dev`), the `DEV` compile flag, the ribboned `AppIcon-Dev`, display name
  `<App> DEV`, and it **includes the test targets** in its `test` action. Xcode Cloud **CI /
  test** workflows use this scheme, and `make verify` builds/tests it locally.

This mirrors what a person sees on the device: the plain app is the product; the DEV-ribboned,
`<App> DEV`-named app is the throwaway. It also makes the CI-vs-release choice obvious: tests
run on `<App> DEV` (the one that *has* tests), archives run on `<App>`.

This supersedes the `<App>` / `<App> Prod` naming referenced in ADR 0006; a release workflow's
scheme is now `<App>` (not `<App> Prod`), and a CI workflow's scheme is `<App> DEV`.

## Consequences

Easy: the names are self-describing, and it is now impossible to point a test workflow at a
scheme with no tests without it being obviously wrong.

Hard: existing apps created under the old convention (e.g. a `<App> Prod` scheme) need renaming
to match, and their Xcode Cloud workflows re-pointed to the correctly-named scheme once. New
apps get it for free from the template. The DEV variant must ship an `AppIcon-Dev` (same art,
a diagonal DEV ribbon) so the two builds are never confused on the home screen.
