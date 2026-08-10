# FD-0009. Humble views: logic lives in a testable type, never in the view body

**Status:** Accepted
**Date:** 2026-07-22
**Enforced by:** on-demand: no direct check. The signal is the coverage number from
`make coverage` (FD-0008), which is automated but sits outside `make verify` and is run when a
human asks for it. It rises as logic leaves views.

## Context

A SwiftUI view has two jobs tangled together by default: deciding *what* to show (rules,
calculations, state transitions) and *rendering* it. When the deciding lives inside the view
body or a view-only helper, it cannot be tested without spinning up a screen, so it shows up as
uncovered and, worse, ships unverified. Measuring coverage on such an app is misleading (ADR
0009): the number is dragged down not because tests are bad, but because the logic is trapped
where tests cannot reach it. The fix is not a measurement trick, it is where the logic lives.

The industry pattern for UI-heavy apps is consistent: keep the view "humble" (it only renders),
and push presentation and business logic into a plain type with no SwiftUI or UIKit import, so it
instantiates in a test target and is driven with plain inputs. Chef and waiter: the chef decides
what is on the plate and is taste-tested rigorously; the waiter just carries it out and is
glanced at (a snapshot), not taste-tested.

## Decision

**Presentation and business logic lives in a testable type, never in a view body.**

- A rule, a calculation, a quantity, a "what to show when", a state transition: it belongs in a
  plain `struct`/`enum`/model/engine with no `import SwiftUI` or `import UIKit`, reachable from a
  unit test with plain inputs. The view calls it and displays the result.
- Views stay humble: layout and binding only. They are proven by the **snapshot** lane, the UI
  smoke tests, and the on-device check, not by unit-test line coverage.
- Coverage therefore measures the logic layer (ADR 0009), which this architecture makes large and
  testable. A file that still holds logic behind an `import SwiftUI` is a coverage *exclusion*
  today and an *extraction backlog item*, not a place to bolt on view-hosting tests.

The tell for a review: if a low-coverage file imports SwiftUI, the logic is trapped in the view
(extract it); if it is pure Swift and low, it simply lacks tests (write them).

## Consequences

New views are built humble from the start, so their logic is testable on day one and coverage is
honest without effort. Existing apps carry an extraction backlog: logic currently inside
view-helpers is pulled out into testable types one at a time, at which point it leaves the
`.coverageignore` and starts counting for real. The tradeoff is a little more indirection (a view
plus its logic type instead of one file), bought back many times over in testability,
reuse, and a coverage number that finally means something.
