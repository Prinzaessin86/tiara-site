# FD-0001. project.yml is the source of truth; the agent never touches the project file

**Status:** Accepted
**Date:** 2026-07-21
**Enforced by:** conform.sh (project.yml present, .xcodeproj gitignored); compliance xcodeproj_ignored
**Amended:** 2026-07-21. Originally specified Xcode-16 synchronized folders with no generator; the factory adopted XcodeGen, so the mechanism was corrected. The principle, one source of truth and the agent never edits the project file, is unchanged.

## Context

`project.pbxproj` is the single most fragile file in an Xcode project. Historically every
added file wrote a new entry into it, which is why it is the classic source of merge
conflicts and corruption. It was never designed to be edited by hand, and it is absolutely
not something to let an autonomous agent rewrite.

We want two things: adding a source file should be a filesystem operation with no project
edit, AND targets, build configurations, schemes, entitlements, and the DEV/PROD split
should be declared in ONE readable place. Xcode-16 synchronized folders solve the first
but not the second: they auto-include files, but they cannot express multiple configs,
per-config bundle ids / entitlements, or shared schemes. Those still need the project file
or a generator.

## Decision

**`project.yml` is the source of truth. XcodeGen generates the project** (`make generate`
→ `xcodegen generate`).

- The generated `.xcodeproj` is **gitignored, never committed.** `project.yml` is what is
  read in review and what is edited to change the project.
- The agent is denied all write access to `.pbxproj` and `.xcodeproj`, in
  `.claude/settings.json` and again in `guard-bash.sh`. Two layers, because one layer is a
  single typo away from none.
- Adding a file to `Sources/` or `Tests/` and regenerating puts it in the build with no
  project-file edit. `make build`/`make verify` regenerate first, so the project is rebuilt
  from `project.yml` + disk every time before compiling.

## Consequences

Easy: clean diffs, no `.pbxproj` merge conflicts or corruption, and the whole project
(DEV/PROD configs, per-config entitlements, schemes) is declared in one readable file the
agent can safely edit.

Hard: anything that consumes the project must generate it first. CI (Xcode Cloud) runs
`ci_scripts/ci_post_clone.sh` → `xcodegen generate` before it builds, and a fresh clone
must `make generate` before opening in Xcode. That cost is small and paid in exactly one
place.

Conformance: `make conform` asserts this ADR mechanically: `project.yml` exists and
`.xcodeproj` is gitignored, so the record can never silently drift from the code again
(which is what happened to the original version of this ADR). See 0006 for how releases
build on the generated project.
