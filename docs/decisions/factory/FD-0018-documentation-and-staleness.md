# FD-0018. What documentation is, where em dashes are refused, and when a document stops being readable

**Status:** Accepted
**Date:** 2026-08-18
**Enforced by:** nothing yet
**Ticket:** Prinzaessin86/_bootstrap#181

## The problem, in one sentence

Two rules about documents are enforced in five places with no decision behind any of them, so
neither has a definition anybody can quote, and a third failure mode, a document that quietly stops
being true, has no mechanism at all.

## Context

Three things drove this, and only the third is new.

**The em dash rule had no scope.** A quality hook banned the character across eleven file types,
line by line, in code, comments and copy alike. Nobody decided that. The rule as stated by Princess
on 2026-08-18 is narrower and differently shaped: em dashes are unwanted in user-facing screens and
in documentation, and nowhere else. Enforcing more makes the gate an opinion about shell scripts and
commit messages, which trains people to work around gates.

It is also enforced in two further places that no decision authorises. `template/.swiftlint.yml`
carries `no_em_dash` at `severity: error` across all Swift, vendored to every app.
`scripts/compliance.mjs` grades a `no_emdash` dimension over all app source, which puts the wider
reading on the board as a score. `compliance.mjs:233` records that this check once passed over 99
unexamined Swift files because it grepped a directory four repos do not have.

**"Documentation" had no definition.** Measured: `_bootstrap` holds 52 Markdown files and every one
is prose meant to be read. `docs/`, the vendored FD set, `README.md`, `SPEC.md`, `ROADMAP.md`,
`CLAUDE.md`, `.claude/rules/*.md`, `SKILL.md`.

**A document can stop being true without becoming finished.** FD-0011 already refuses a finished
document, and its Context names this case directly: "a superseded brief: each was true when written,
and each stops being true the moment the code moves on." Its mechanism only covers documents
somebody decided were finished and moved. A mockup is never finished. It is replaced, and it stays
where it was, looking current.


## Decision

**Documentation is any Markdown file**, `*.md` or `*.markdown`, anywhere in the repository. Not a
location. A document does not stop being documentation by sitting outside `docs/`.

**Em dashes are refused in documentation and in user-facing screens, and nowhere else.** The
definition of a user-facing screen is the one `verify-on-stop.sh` already uses to decide when device
proof is required, so the factory has one answer to that question rather than two. Within a screen
file the rule applies to string literals only: file names, asset names and accessibility identifiers
are exempt, because none of them is text a person reads. Comments are exempt everywhere. Shell,
YAML, JSON, configuration and non-screen source are not scanned.

**The two wider enforcements narrow to match.** `no_em_dash` in `template/.swiftlint.yml` gains
`match_kinds: [string]` and a path filter for screen files, which is exactly the distinction above
and which SwiftLint custom rules support natively. The `no_emdash` compliance dimension narrows to
the same set.

**Every file under `docs/design/` carries a `**Status:**` line**, valued `LIVE` or `SUPERSEDED`.
`conform` refuses a file carrying neither, so the marker cannot be omitted by accident.
`guard-bash` refuses to read one marked `SUPERSEDED`, in both layers, exactly as FD-0011 does for
`docs/archive/`, and the refusal names where the current document is.

This extends FD-0011 rather than replacing it. `docs/archive/` remains the one place a **finished**
document lives, and moving one there remains right when work is closed. The Status header is for the
other case: a document **replaced** while its subject is still live, where moving it would separate
it from the material it belongs beside.

A `SUPERSEDED` header names its replacement. A marker saying a document is dead without saying what
is alive sends the reader looking, which is the failure the header exists to prevent.

## Consequences

An agent that opens a superseded design document is stopped and told where the current one is,
rather than building to a mockup that was replaced. That is FD-0011's protection extended from
closed findings to replaced ones.

The em dash gate stops being an opinion about shell scripts. It refuses in exactly two categories, a
person can predict it without reading the hook, and both rules are written here rather than inferred
from behaviour.


## Alternatives considered

**Doing nothing.** The status quo, and it is what produced this. Three enforcement points with no
decision behind them, a definition nobody can quote, and a lint config that contradicts the hook it
ships beside. 

**Amending FD-0011 instead of writing a new decision.** Genuinely considered, and the closest call
here. FD-0000's amendment clause permits correcting a record that drifted from practice, and the
subject matter is identical. Rejected because FD-0011's title is "Finished documents are not
maintained", a superseded mockup is not finished, and extending it to a case its own title excludes
damages the property FD-0000 names as the reason the numbering exists: that an id "can be quoted out
of context without ambiguity". The em dash rule and the documentation definition also have no home
in FD-0011 under any reading, so a new decision was needed regardless.

**Superseding FD-0011.** Rejected outright. FD-0011 is accurate and actively enforced.

**Defining documentation as what lives under `docs/`.** Narrower and simpler. Rejected because it
would exempt `README.md`, `SPEC.md` and `CLAUDE.md`, which are documentation on any reading. 

**Extending the Status header to every brief, handover and audit in the repository** rather than
just `docs/design/`.Rejected for now as more files than the demonstrated problem justifies, and it can widen
later without contradicting anything here.

**Detecting staleness automatically** rather than declaring it, for example by comparing a design
document's date against the newest commit touching the views it describes. Rejected: heuristic,
noisy.


## Open, and deliberately not decided here

**Three exemptions a lint rule cannot express.** `match_kinds: [string]` gives the comment and string
distinction, but asset names, symbol names and accessibility identifiers are all string tokens, so
SwiftLint will still flag them where the hook allows them. That is the strict direction and costs a
refusal somebody reads, where the comment case cost a refusal nobody could satisfy. Closing it means
moving the rule out of SwiftLint entirely, which is a larger decision than this one.
