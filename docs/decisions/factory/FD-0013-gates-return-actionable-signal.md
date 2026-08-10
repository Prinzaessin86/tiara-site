# FD-0013. Every gate returns an actionable signal

**Status:** Accepted
**Date:** 2026-08-09
**Enforced by:** check gate_fix_instructions (fails if any conform check or gate carries an empty
or non-actionable fix instruction)

## Context

A check that fails without saying what to do is itself a failure: it stops work but gives the
person stopped nothing to act on, which is functionally the same as no gate at all, just louder.
This is the same lesson as FD-0002 applied to messaging instead of to enforcement: a gate that
fails closed but fails mute still leaves someone stuck. In a one-person shop there is nobody to
ask at eleven at night, so the fix string is the whole of the institutional knowledge.

The compliance checks already have this property today. Every `fix:` field in
`scripts/compliance-explain.mjs` is non-empty and names a concrete command or a specific file,
so this decision records a property the factory already has rather than repairing a breach. What
it guards against is drift, and the drift is already visible: `coverage_scope` points its
`verify:` field at `~/Developer/_handover-2026-08-01/scripts/coverage-compare.sh`, a dated
handover directory outside the factory, and `factory_current` names two remediation paths by
hand. Nothing asserts that any of those paths still exist or still describe the remedy. A field
whose target is renamed keeps passing, because what makes an instruction actionable is not a
property anything currently measures.

## Decision

**Every hook, gate, and conform check must carry a non-empty, actionable `fix:` instruction:** a
concrete next step, ideally a command or a specific file to change, not a pointer to background
reading.

## Consequences

Easy: a failing check tells the person who hit it exactly what to run or change next, which
shortens every incident caused by a gate firing. Hard: every existing check has to be audited for
this property once, and any check whose remediation moves between scripts or documents needs its
`fix:` field kept in sync, which is an ongoing maintenance cost rather than a one-time fix.

The known weakness is that `gate_fix_instructions` can only test non-emptiness, since
"actionable" is not a machine property, so the check will assert less than the decision requires.
The cheap upgrade that closes most of the gap is to assert that any file path named in a `fix:`
exists on disk and any command named is executable, which turns a renamed script from a silent
pass into a failure.
