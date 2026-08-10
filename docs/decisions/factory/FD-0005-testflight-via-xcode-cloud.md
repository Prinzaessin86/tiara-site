# FD-0005. Releasing to TestFlight via Xcode Cloud, triggered by a build-number bump

**Status:** Accepted
**Date:** 2026-07-21
**Enforced by:** the release workflow; compliance release_workflow

## Context

Shipping an iOS build needs three things: an archive, code signing, and an upload to App
Store Connect. **Code signing (a distribution certificate plus provisioning profiles) is
the most fragile part of the whole pipeline** and the classic source of "works on my
machine" failures. For a solo developer we want releases that are deliberate (not every
push), need zero local certificate management, and do not tie up the Mac for a ten-minute
archive.

An earlier attempt put a local `make testflight` in the Makefile (`xcodebuild archive` +
upload via the App Store Connect API key). It required working local signing, it was never
finished (`ExportOptions.plist` missing, `release.env` not even gitignored), and it was
never run. Keeping it alongside a second mechanism is exactly the drift `make conform`
exists to prevent, so it is retired, not kept as an alternative.

## Decision

**Releases run on Xcode Cloud with Apple-managed signing. There is exactly one release
mechanism.**

- **Trigger = a build-number bump.** The build number lives in `Config/Version.xcconfig`
  (`CURRENT_PROJECT_VERSION`, wired via `configFiles` for every config). The Xcode Cloud
  workflow's start condition is *Branch Changes on `main`, filtered to that one file*, so a
  deliberate bump ships and ordinary commits never do. `MARKETING_VERSION` stays in
  `project.yml` (Tiara's version badge reads it there).
- **Signing is managed by Xcode Cloud.** No certificates or profiles are created, stored,
  or committed anywhere.
- **The project is generated on the runner.** `ci_scripts/ci_post_clone.sh` runs
  `xcodegen generate` before the build, because the `.xcodeproj` is not committed (ADR 0001).
- **Export compliance is declared once.** `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
  (or the `ITSAppUsesNonExemptEncryption` Info.plist key for a real Info.plist) so TestFlight
  never prompts on upload.
- **`release.yml` is the per-app opt-in marker** (committed, non-secret). Its presence means
  "this app ships to TestFlight"; Tiara reads it for the ✈ badge. The App Store Connect API
  key (`.p8`) lives only in CI / the developer's App Store Connect account, never in the repo.
- Internal testers receive every processed build with no App Review.

## The build-number gotcha (learned the hard way on PagingDrDaddy, 2026-07-22)

**Xcode Cloud OWNS the uploaded build number.** It stamps `CFBundleVersion` from its own
per-app counter and overrides everything else, including `Config/Version.xcconfig` and any
`ci_post_clone`/`ci_pre_xcodebuild` script that writes the number (this was proven: a script
that set the number to 24 still uploaded a lower number and was rejected). Do not fight it.

For a **brand-new app** this is fine: the counter starts at 1 and climbs. For an app that
**already has manually-uploaded TestFlight builds** (e.g. up to build 9), the counter starts
at 1, which is *below* the existing builds, so every upload is rejected with "The bundle
version must be higher than the previously uploaded version." The fix, done ONCE when
adopting Xcode Cloud for such an app: **set the next build number in App Store Connect above
the highest existing build** (App Store Connect → the app → set the Xcode Cloud build number).
Then it uploads and auto-increments from there. Keep `Config/Version.xcconfig` bumped in step
(both increment by 1 per release) so the trigger value and the real build number stay aligned.

## One product per app (learned the hard way on PagingDrDaddy + SparkleReef, 2026-07-22)

**Every app is its OWN Xcode Cloud product.** A source repository can belong to only ONE
product, and Xcode Cloud's "additional repositories" are for *shared dependency code* (a
framework in its own repo) ONLY, never a second app. Adding one app as an additional
repository of another app's product, or repointing a single product's primary repository
between two apps, causes an endless ping-pong: each setup steals the other app's product,
and onboarding the second app fails with "the project name is already taken by another app."

Onboard each app from its **own** App Store Connect app page (App Store Connect → the app →
Xcode Cloud → Get Started), which creates a per-app product. Never add another app as an
additional repository.

**Recovery when it tangles:** delete the whole product (the GUI blocks deleting the *last*
workflow, but you can delete the product; or `DELETE /v1/ciProducts/{id}` via the App Store
Connect API — deletion is async and the list endpoint caches, so verify with a direct
`GET /v1/ciProducts/{id}` → 404). TestFlight builds survive (they live on the app record, not
the product). Then re-onboard each app fresh, one at a time, from its own page. The whole
Xcode Cloud state is inspectable read-only via the ASC CI API (`/v1/ciProducts` +
`/primaryRepositories` + `/additionalRepositories` + `/app` + `/workflows`), which is far
clearer than Xcode's local UI when diagnosing a tangle.

## Swift packages need Package.resolved (learned on SparkleReef + Firebase, 2026-07-22)

Xcode Cloud runs with **automatic dependency resolution off** and requires a committed
`Package.resolved` (at `<App>.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`).
But that file lives *inside* the generated, gitignored `.xcodeproj`, so it is never committed,
and the archive fails: *"a resolved file is required when automatic dependency resolution is
disabled."* Fix: `ci_scripts/ci_post_clone.sh` runs `xcodebuild -resolvePackageDependencies`
after `xcodegen generate`, which writes the `Package.resolved` before the archive. This is a
no-op for a package-free app (like PagingDrDaddy, which is why it never hit this), so the
template does it unconditionally. Note: the failure looked like a missing *repository grant*
but was not — public Firebase/Google/Apple package repos resolve without a grant.

## Consequences

Easy: no local signing, no certificates, cloud builds never tie up the Mac, and a
build-number bump is a clean, deliberate "ship it" that leaves a trace in git.

Hard: the Xcode Cloud workflow is created once per app in Xcode's Integrate menu (a GUI
step, ~10 min, not scriptable). The free tier is 25 compute-hours per month across all apps;
an archive is 5–15 minutes, so occasional per-app releases stay free.

Conformance: `make conform` asserts there is exactly one release mechanism — the
`Config/Version.xcconfig` trigger present and wired, `ci_post_clone.sh` present, and the
retired `make testflight` targets absent — so a second, parallel release path can never be
introduced unnoticed again. (That silent parallel-mechanism drift is the exact failure this
ADR and the conformance check were written in response to.)
