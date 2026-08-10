# FD-0003. Quality hooks must fail loud on tool error

**Status:** Accepted
**Date:** 2026-07-22
**Enforced by:** the quality hooks; compliance gate checks

## Context

ADR-0002 established that a hook fails closed when it cannot read its input, find its
parser, or find its tools. This ADR covers the sibling failure it did not name: the tool
is present and runs, but the invocation ERRORS, and the hook swallows the error.

The `swift-quality.sh` lint step read:

    LINT=$(swiftlint lint --quiet --path "$FILE" 2>/dev/null)

SwiftLint 0.65 removed the `--path` flag. Paths are now positional. So this line errored
with `Error: Unknown option '--path'` and exit code 64. The `2>/dev/null` discarded the
message, stdout came back empty, the empty result looked exactly like a clean file, and
the hook exited 0. The gate reported success while linting nothing, on every Swift edit,
for as long as that SwiftLint version was installed.

This is the same worst case as ADR-0003: a gate that checks nothing is indistinguishable
from a gate that simply had nothing to flag. It looks fine indefinitely. The difference is
only the cause. In 0003 a dependency was missing. Here a present tool was called wrongly
and its failure was hidden.

It was found the only way these are ever found: by feeding the hook real input and
watching the result, not by reading the script.

## Decision

1. **A hook fails loud on tool error, it never swallows it.** If the tool cannot run, that
   is not a pass. It is a gate that is not functioning, and it must exit 2 with the tool's
   error shown, so the failure is impossible to mistake for success.
2. **Do not blanket-redirect a tool's stderr to `/dev/null`.** Capture it. The error text
   is the evidence that tells you the gate broke.
3. **Know the tool's healthy exit codes and check them.** For SwiftLint, exit 0 (clean)
   and exit 2 (violations found) are the only healthy outcomes. Any other exit code means
   the invocation itself failed and must be surfaced.
4. This is a general rule for every quality hook, not a SwiftLint patch. The rule lives in
   the `swift-quality.sh` header comment so it travels with the hook to every app built
   from the template.

## Consequences

Easy: the gate is trustworthy, which is the only property a gate has that matters.

Hard: a wrong invocation or a tool that changed its flags now stops work loudly instead of
degrading into a silent no-op. That is the correct trade, and the same one 0003 made.
Noisy failure beats silent absence of protection.

Note: like 0003, this ADR exists because the bug was made and shipped, not because it was
foreseen. That is what ADRs are for.
