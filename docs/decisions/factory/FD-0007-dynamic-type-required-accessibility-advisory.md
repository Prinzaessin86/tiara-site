# FD-0007. Dynamic Type is required in every app; other accessibility checks are advisory

**Status:** Accepted
**Date:** 2026-07-22
**Enforced by:** compliance dynamic_type (heuristic) and the a11y audit lane

## Context

Readability is the one non-negotiable design rule. A person who sets a larger system font size
must get larger text in the app, not a fixed layout they cannot read. Custom variable fonts
(Quicksand pinned through `Typeface.quicksand(size:)`) are pinned at fixed point sizes by
default, which quietly opts every screen OUT of Dynamic Type. Apple's accessibility audit
(`performAccessibilityAudit`) catches this, along with contrast, hit-region size, clipping,
labels, and traits. But most of those are judgement calls (a decorative glyph a hair under the
contrast line is a design decision, not a bug), so auditing them as a hard build gate would red
the pipeline on choices a human should make. Dynamic Type is different: it is a floor, not a
judgement call.

## Decision

**Every app must support Dynamic Type.** Text scales with the user's system font-size setting.
Use `UIFontMetrics` / `@ScaledMetric` (or `.font(...)` styles that scale) so the type ramp
grows and shrinks; never ship a screen whose text is frozen at fixed point sizes. A layout may
cap growth where it genuinely must, but the default is: text responds. This is verified by
watching it on a device at a large accessibility text size, the same "true on device" bar as
any feature.

**All other accessibility checks are advisory, not gates.** The contrast maths (`ContrastTests`)
and the rendered `performAccessibilityAudit` run in a separate `make a11y` lane that REPORTS
findings and never fails `verify`. They are run on demand when UI or the design system changes.
A finding is a to-do, not a broken build. Contrast for reading text still has a hard target
(4.5:1 body, 3:1 large/UI) as a design rule, but it is enforced by eye and the advisory lane,
not by blocking CI.

## Consequences

Dynamic Type support is real work the first time (scaling a variable-font ramp), so it is its
own work package per app, not a side effect of a feature. The advisory lane makes the gap
visible without holding the gate hostage. The tradeoff is honest: the gate stays green and fast,
and the human keeps ownership of the readability calls that a machine should not make for them,
while the one floor that is not negotiable, text that scales, is written down as required.
