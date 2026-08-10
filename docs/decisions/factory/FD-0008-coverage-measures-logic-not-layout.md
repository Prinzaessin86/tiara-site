# FD-0008. Coverage measures logic, not layout: a ratchet floor on the code that matters

**Status:** Accepted
**Date:** 2026-07-22
**Enforced by:** coverage.sh and .coverageignore; the ratchet floor

## Context

Coverage was measured against the whole app target from unit tests only. For a SwiftUI app that
buries the signal: every `*View.swift` and `#Preview` is counted as uncovered (unit tests do not
render views; only UI tests do, and those were excluded from the measurement), so a fully-tested
engine reads as a low whole-app number. PackMagic measured ~20% while its logic files (the packing
engine, reminder schedule, XLSX writer, catalogs, Theme) were at ~100%. That is the well-documented
anti-pattern: layout code floods the number and hides the coverage that matters.

Industry practice is consistent on the fix:
- **Measure logic, not layout.** Exclude view/layout files and `#Preview` blocks from coverage; a
  number dominated by untested-by-unit views is noise.
- **80% is the ceiling of usefulness, not a target.** Beyond ~85% the cost rises sharply for little
  gain; most mature teams sit 70-85%. A hard coverage *target* incentivises gaming (fake tests to
  hit a number), so the quality of tests matters more than the percentage.
- **Tier by criticality.** Core/data-integrity logic held highest, UI lower, config excluded.
- **Ratchet from a floor at or just below current coverage**, rising as it improves; never an
  absolute wall that blocks all work, and never the sole gate on a release.

## Decision

**Coverage is a ratchet-only floor on LOGIC coverage, with the view/layout layer excluded from the
measurement.**

- The coverage tool excludes the layout layer: SwiftUI view files and `#Preview`s do not count. What
  is measured is the logic that unit tests can and should cover (engines, services, models, pure
  helpers). Views are proven by the UI smoke tests, the snapshot lane, and the on-device check, not
  by line counting.
- The floor lives in `.coverage-floor`, starts at the current measured logic coverage minus a small
  buffer, and only ever rises (ratchet). There is no absolute vanity target to write hollow tests
  against; the rule is "do not go backwards", plus "new logic ships with its tests".
- Coverage is advisory. It is not part of `make verify` and never hard-blocks a release on its own;
  the gate is `make verify`, and the human's device check is the final word.
- Criticality tiering is a judgement, not a config: data-integrity and dose/quantity math are held
  near-total; ordinary logic follows the ratchet; layout is excluded.

## Consequences

The reported number becomes truthful: it reflects how well the logic is tested, so a floor like 65%
(or higher) is both meaningful and reachable for a well-tested app, instead of an impossible
whole-app-including-views figure. The cost is one piece of config per app: a coverage ignore list
for the view/layout files (kept next to `.coverage-floor`), which `scripts/coverage.sh` honours.
Existing apps' floors are re-baselined once against the logic-only measurement. Coverage stops being
a number to game and goes back to being a quiet ratchet on the code that can actually carry tests.
