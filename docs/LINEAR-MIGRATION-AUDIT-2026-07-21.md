# Linear → GitHub migration: open-ticket codebase audit (2026-07-21)

Every **open** ticket migrated from Linear was checked against the app's **actual Swift code**
(not docs/SPEC) to decide: (a) is it genuinely still open, and (b) is it still relevant.
Verdicts: STILL OPEN · PARTIALLY DONE · ALREADY DONE · OBSOLETE.

**Quick wins — tickets that are ALREADY DONE and can be closed now:**
- Tentaclepit **TEN-132** (full JSON export), **TEN-130** (allergy PDF page), **TEN-122** (allergy badge on med cards).

---

## Tentaclepit (BloopPoop) — 13 open

- **TEN-135: Dose model diverged / four competing systems** — **STILL OPEN.** All four dose systems still coexist in `Models/Medication.swift` (legacy scalar 193-194, legacy slot maps 197-198, count+strength 210-212, dead map 207). `mg(for:)` (248-251) guards on count not strength → "0 mg" shadowing bug; `init` never sets strength/counts. **Keep open.** Start WP1: make count+unit the primitive, fix `mg(for:)` to return nil when strength==0.
- **TEN-133: Nutrition & Water (Fuel tab) + weekly backup** — **STILL OPEN.** No Fuel tab in `RootTabView`, no nutrition/water models, no scheduled backup (`BackgroundTaskScheduler` 51 lines, none). **Keep open.** Build water+food SwiftData models + Fuel tab first.
- **TEN-134: Code audit remediation (43 findings)** — **PARTIALLY DONE.** Some done (SaveFailureCenter wired, no-op passes removed, @Query patterns). Umbrella of 43 — can't confirm all from code; overlaps TEN-135. **Revise:** split per-WP, close only verified.
- **TEN-35: Withings OAuth** — **PARTIALLY DONE.** `WithingsAuthManager` is an explicit stub (no flow/token/API). `WithingsTokenStore` complete but unused; models exist. UI shows "Coming soon". **Keep open.** Implement Phase-1 OAuth (DEV first).
- **TEN-132: Full JSON export** — **ALREADY DONE.** `FullJSONExporter` serializes all 14 schema models; one-tap UI in `DataExportSettingsView` 205-236. **Close** after on-device verify.
- **TEN-51: Oura Ring (future)** — **STILL OPEN, parked.** No Oura code; existing HealthKit read set covers the metrics once Oura→HealthKit. Gated on hardware. **Keep parked.**
- **TEN-130: Allergies PDF page** — **ALREADY DONE.** `pdfIncludeAllergies` toggle + `MedicationPDFReport.generateAllergies` dedicated page, wired in export. **Close** after device verify.
- **TEN-122: Allergy badge on med cards** — **ALREADY DONE.** `BloopBadge("⚠ Allergy")` at `MedsTabView:587-589` + detail view. **Close.**
- **TEN-127: Home tab energy & hydration (HealthKit)** — **STILL OPEN.** HealthKit read set lacks `dietaryWater`/`dietaryEnergyConsumed`; no summary on `TodayView`. **Keep open.** Add reads + day-scoped card.
- **TEN-36: AI Trends tab (Claude, streaming)** — **PARTIALLY DONE.** Trends tab calls Claude (`claude-sonnet-4-6`) but: no `TrendsAnalysis` model (transient state), payload is only temp+cycle (not all data), and NOT streamed (single request). **Revise** to shipped scope or broaden.
- **TEN-47: iCloud two-device sync verify + conflict doc** — **STILL OPEN.** Manual task; PROD CloudKit configured, DEV local-only, no verified-test doc. **Keep open.** Do the two-device test on TestFlight, document conflict resolution.
- **TEN-103: AI med-interaction + liver-enzyme checker** — **STILL OPEN.** No AI check button, no interaction code. Spec-first ticket. **Keep open.** Lock spec first.
- **TEN-49: Labs OCR (VisionKit)** — **STILL OPEN.** `LabResult` model exists (with `wasScanned`/`sourceImagePath`) but no OCR/scan UI/writer. **Keep open.** Build VisionKit extract + manual-confirm screen.

## Poda (PodaProject) — 16 open

- **PRI-34: UIAppearance global styling vs future modals** — **STILL OPEN.** Global proxy pattern in `DesignSystem.swift:303-335`; no modals yet so conflict latent. **Keep open**, fix when first sheet added (scoped appearance).
- **PRI-32: Real stuffie photos in CharacterAvatar** — **STILL OPEN.** `CharacterAvatar` still `Text(character.emoji)`; asset catalog has no character imagesets. **Keep open.** Add imagesets + optional `imageName`.
- **PRI-119: Remove dead Notification.Name exts + 4 test suites** — **STILL OPEN.** 5 dead `Notification.Name` exts (never posted/observed); 4 named test suites absent though the code they'd test exists. **Keep open.** Delete dead exts + add 24h auto-revert test first.
- **PRI-31: Dose display — actual due times** — **PARTIALLY DONE.** `doseRow` already shows "Taken at…/Due at…/Due now"; but title still `"Dose N"` and no relative "in N min". **Revise:** close as effectively delivered, or move time to title + add countdown.
- **PRI-37: iCloud sync + Mac blocking** — **STILL OPEN.** Zero CloudKit/iCloud code; persistence all UserDefaults. **Keep open** — planning session (store choice) first.
- **PRI-58: Leave-house mode (location + NFC)** — **STILL OPEN.** No CoreLocation/CoreNFC. **Keep open** — plan first.
- **PRI-64: Real WhatsApp/iMessage texts** — **STILL OPEN.** No external-messaging code. **Keep open.** Prototype `wa.me`/`sms:` from a notification action first.
- **PRI-40: Apple Watch haptics companion** — **PARTIALLY DONE.** `WatchBridge`/`FeedbackManager.sendWatchHaptic`/`PodaWatch` target all present; missing Watch-status Settings UI + device verify. **Revise** to "add status UI + verify".
- **PRI-27: Shield "Open Poda" via URL scheme** — **STILL OPEN.** No `poda://` scheme, no `ShieldActionExtension` (only a config data source). Button just dismisses. **Keep open.** Register scheme + add action extension.
- **PRI-118: Share BlockContext across targets** — **STILL OPEN.** Both hand-sync sites live; `BlockContext` (`Models.swift:316`) excluded from extension targets. **Keep open.** Move enum to `SharedActivityDefinitions.swift`.
- **PRI-60: Per-app daily usage time limit** — **STILL OPEN.** No `applicationUsageThreshold`/`eventDidReachThreshold`; blocking is all-or-nothing. **Keep open.** Prototype `DeviceActivityEvent` thresholds.
- **PRI-41: Intention gate (algebra + reason via App Intents)** — **STILL OPEN.** No App Intents/gate code. **Keep open** — large; start with one `AppIntent`.
- **PRI-57: Verify meds taken with optional photo** — **STILL OPEN.** No photo/camera code; `DoseRecord` has no image. **Keep open.** Add `photoFilename` + PhotosPicker.
- **PRI-56: GitHub Actions CI** — **STILL OPEN.** No `.github/` dir; tests exist but nothing runs them. **Keep open.** Add `ci.yml` running `xcodebuild test`.
- **PRI-39: Haptics/sound overhaul** — **STILL OPEN, deferred.** `FeedbackManager` unchanged; `[self]` asyncAfter captures still present (safe only because singleton). Gated behind v1.1. **Keep parked.**
- **PRI-26: 10pm shield cross-midnight interval may misfire** — **STILL OPEN, verify.** `scheduleTenPmShield` builds the single `22→0` interval (not split). **Keep open.** Run the repro; split into two monitors only if it misfires.

## Dressie — 2 open

- **PRI-102: CloudKit sharing (both users, own iPhones)** — **PARTIALLY DONE.** Architecture fully built (async `prepareShare` w/ timeout + loading UI, `UICloudSharingController`, external-binary photos, two-store container, accept path) but the core acceptance test (verified two-device data+photo sync) is **not confirmed** — `resyncWardrobeIntoShare()` may not relocate pre-mirrored items; CLAUDE.md logs "NOT yet confirmed on device". **Keep open.** Run the two-device / two-Apple-ID test with Sharing Diagnostics.
- **PRI-101: Push notifications (cute reminders, both)** — **PARTIALLY DONE.** Full LOCAL notification layer (role-based, daily/morning, manual nudge, outfit-request) but NO remote push (no `registerForRemoteNotifications`/`CKDatabaseSubscription`) so it can't truly cross devices; several scenarios missing; message pools under the 10+ bar. **Keep open (revise).** Depends on PRI-102; add local triggers + expand pools now, push later.

## Bubbles — 10 open (7 already done — Bubbles is largely built)

- **PRI-149: Audit fixes 2026-07-06 (sequenced squash queue)** — **ALREADY DONE.** Every Brief 2-5 item verified in code (day-window from `PlanSettings.dayWindow()`, zero `*Material`, ~168° gradients, `Theme.font` launch view, 44pt targets, heart a11y label, reflow/placement tests). Only the checkboxes were never ticked. **Close.**
- **PRI-123: Custom "little scenes" chip icons** — **PARTIALLY DONE.** Timeline chips already custom (`BubblesChipIcon` in `BubblesIcons.swift`), but squash is still a **star** (spec: burst) and walk a **cloud** (spec: paw print). **Revise:** redraw those two + sign-off.
- **PRI-134: Richer pastel gradient + dreamy bubbles background** — **ALREADY DONE.** `FloatingBubblesBackground` = signed-off Option C, exact hex, 3 depth layers w/ reduceMotion fallback. **Close.**
- **PRI-133: Purge em-dashes from copy** — **ALREADY DONE.** No em/en-dash in any user-facing string; offending `Vibe.swift:163` fixed. **Close.**
- **PRI-109: All timeline items draggable (incl. fixed islands/appts)** — **ALREADY DONE.** `moveSlots` reorders across all sources; only active/paused locked; commitments show "moved" note. **Close.**
- **PRI-124: Cozy sound assets for SoundService stubs** — **STILL OPEN.** `SoundService` still plays system-sound placeholders; no audio assets in repo. **Keep open.** Add `bloop/completion/ambient.caf` + `AVAudioPlayer`.
- **PRI-112: Time-counting redesign ("X on this", drop "banked")** — **ALREADY DONE.** `SlotRow.infoRow` shows live "N min on this" + quiet planned; "banked" only in code comments. **Close.**
- **PRI-111: Task placement rules (before/after time or task)** — **ALREADY DONE.** Full stack: `PlacementRule` model, `sortForPlacementRules` engine, CaptureSheet UI, tests. **Close.**
- **PRI-110: Islands repeatable within a day (N×, ≥ X hrs apart)** — **ALREADY DONE.** `Anchor.timesPerDay`/`minHoursBetween`, `PlanningService.propose` chunks + spaces, AnchorsView steppers, "N×" badge, tests. **Close.**
- **PRI-2: Decide Poda → Bubbles rabbit-hole handoff signal** — **STILL OPEN.** Cross-app design decision; app group configured but no signal-reading/day-blessing logic. **Keep open.** Decide (shared app-group flag is lowest-friction), then spin off a build ticket.

## SparkleReef — 5 open (2 obsolete, 3 partially done)

- **PRI-146: Sparkle Reef polish, rework & gaps** — **PARTIALLY DONE.** Most items shipped (Quicksand, `SRTopBar`, `SRScreen`/`@ScaledMetric`, `SRLeaveDialog`, seat-button rule, AX suite, Poda sheets). The flagged "50-sparkle auto-mint" was **deliberately replaced** by good-sport/weekly-luck/wrong-vet coupons (retired, not missing). Still open: Bumble vet panel + Bubbles feedback are still full-screen `.overlay` scrims, not native `.sheet`. **Revise:** tick shipped items, delete the retired auto-mint line, keep only the two overlay→sheet conversions.
- **PRI-143: Cuddle Coupon Jar UI/minting/redemption** — **PARTIALLY DONE (premise stale).** Jar UI + two-tap spend/accept handshake fully built (Firebase-backed). But the two locked earning paths (50-sparkle auto-mint, Daddy-mint-anytime) were **retired** — replaced by good-sport/wrong-vet/weekly-luck. **Revise/close:** jar+redemption done; minting spec superseded.
- **PRI-136: Live multiplayer + in-app chat + CloudKit persistence** — **OBSOLETE.** Goal (live 2-phone ~1s sync + presence) is fully built on **Firebase** per-realm sessions, not CloudKit (which survives only as DEV-only dead scaffold). In-app chat has zero code and was formally cut (per PRI-147). **Close as done-differently.** Remaining real gap: two-device Firebase acceptance test.
- **PRI-142: Realm — Bumble's Tumble (co-op stacking)** — **OBSOLETE.** The stacking design (Cuddle Pile, Catch tokens, Bumble Hug) doesn't exist; the Bumble realm was rebuilt as a **co-op maths-checking tower** (fully shipped). CLAUDE.md §20 lists the ticket's mechanics as "GONE (do not re-introduce)." **Drop/close.**
- **PRI-147: Sparkle Reef audit (spec reconciliation + live gaps + copy)** — **PARTIALLY DONE.** Most concrete code items already fixed (Bumble tagline, Tyler `SparkleScore` persistence + coach card, stackBlock guard, `sendSweetTaskFired`, JSON `sendFullState`, seeded Sweet Task deck, false-copy removals, big delete-list mostly done). Item 19 (dead invite links) now moot (deep-link system removed, single-linked-reef model). Still open: item 11 (two overlay→sheet), item 12 (Poda gunk regrowth unsynced — `PodaDiveEngine.tick` uses unseeded RNG) + the doc/spec reconciliation packages. **Revise:** tick completed items; keep only 11, 12, and the doc packages (this ticket is their record).

---

## What to do next (recommended triage)

**Close now — ALREADY DONE / OBSOLETE (12):**
Tentaclepit TEN-132, TEN-130, TEN-122 · Bubbles PRI-149, PRI-134, PRI-133, PRI-109, PRI-112, PRI-111, PRI-110 · SparkleReef PRI-136, PRI-142.

**Revise/reconcile — PARTIALLY DONE (10):** TEN-134, TEN-35, TEN-36 · PRI-31, PRI-40 · PRI-102, PRI-101 · PRI-123 · PRI-146, PRI-143, PRI-147.

**Genuinely still open (the real backlog):** the rest — mostly greenfield features (Poda: iCloud sync, location/NFC, WhatsApp, App Intents gate, per-app limits, shield URL scheme, shared BlockContext, CI; Tentaclepit: Fuel tab, hydration summary, Labs OCR, Withings, AI checker; Bubbles: sound assets, Poda→Bubbles handoff decision).

