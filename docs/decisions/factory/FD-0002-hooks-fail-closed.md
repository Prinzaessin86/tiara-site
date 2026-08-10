# FD-0002. Hooks fail closed, and are tested with real input

**Status:** Accepted
**Date:** 2026-07-22
**Enforced by:** the hooks themselves; compliance gate_hooks and gate_wired

## Context

The first version of `guard-bash.sh` in this project looked correct. It had cases for
`rm -rf /`, for the API key file, for the production CloudKit container. It had a comment
in its own header reading "fail loud, never fail open".

It was tested by piping real hook JSON into it. Every single dangerous command was
allowed, including `rm -rf /`.

The reason: it used `jq` to parse its input, `jq` was not installed, the parse silently
produced an empty string, and the script's own guard clause said that an empty command
should exit 0. A missing dependency turned the safety gate into a no-op.

This is the worst possible failure mode, because a gate that allows everything is
indistinguishable from a gate that has simply never had anything to block. It would have
looked fine for months.

## Decision

1. **Every hook fails closed.** If a hook cannot read its input, cannot find its parser,
   or cannot find its tools, it BLOCKS and says why. It never shrugs and exits 0.
2. **Every hook has a fallback parser.** `jq` if present, otherwise `python3`, and if
   neither, refuse.
3. **A hook is not considered working until it has been fed real input and watched
   blocking a real command.** Reading the source is not verification. This is the same
   rule as "true in code is not true on device", applied to the tooling itself.

## Consequences

Easy: the gate is trustworthy, which is the only property that matters in a gate.

Hard: a broken toolchain now stops work loudly instead of degrading quietly. That is the
correct trade. Noisy failure beats silent absence of protection.

Note: this ADR exists because the bug was made, not avoided. That is what ADRs are for.
