# FD-0017. The portfolio is exactly the Tiara registry, and a repo outside it is not a gap

**Status:** Accepted
**Date:** 2026-08-17
**Enforced by:** nothing yet

## The problem, in one sentence

Which repos are in scope is enforced identically by every tool and stated nowhere an agent can read,
so the question gets asked again on every fresh context.

## Context

The behaviour is already correct and already consistent. `compliance.mjs` scores `data.apps`,
Tiara's `discoverBoards()` iterates `data.apps`, and `vendor-factory.sh` and `make-board-ticket.sh`
read the same list. Neither the scanner nor the page ever enumerates the account. Nothing needs
building.

What is missing is the sentence. There are more repos on the `Prinzaessin86` account than there are
registered apps, and more folders under `~/Developer` than there are on the account. An agent that
opens either sees repos with no factory layer and has nothing telling it that most of them are
permanently out of scope, so it guesses, or it files a ticket about a gap that is not one.

**The exclusion set cannot be inferred.** Measured against the GitHub API on 2026-08-11 and
corrected against the filesystem on 2026-08-16 under `_bootstrap#122`:

| Repo | What it is | What a scan sees |
|---|---|---|
| `Loop` | fork of `LoopKit/Loop` | `isFork: true` |
| `cgm-remote-monitor` | fork of `nightscout/cgm-remote-monitor` | `isFork: true` |
| `xdripswift` | a copy of xDrip4iOS, described as a SmartGuide fork | `isFork: false` |
| `dlpchecker` | Princess's own, archived | on the account |
| `tiara` | the repo that holds the registry itself | on the account |
| `Threadmap` | Princess's own, out by decision | on the account, `isFork: false` |
| `Dailylog` | Princess's own, unclassified | on the account |
| `HelloDaddy` | Princess's own, unclassified | on the account |
| `bootstrap_model` | Princess's own, unclassified | on the account |
| `Meds` | Princess's own, an offline PWA, local only | no remote at all |
| `CandyArcade` | Princess's own, local only | no remote at all |
| `CandyCart` | Princess's own, local only | no remote at all |

Two rows kill the obvious heuristic. `xdripswift` is a copy of somebody else's app and GitHub
reports it as `isFork: false`, so "skip forks" is wrong on it. `Threadmap` is Princess's own work,
on the account, not a fork, and is out anyway: no test on the repo could have found that.

The last three rows kill the method rather than the heuristic. They have no remote, so an account
enumeration can never see them however often it is re-run. Any list claiming to enumerate what is
out of scope has to read the filesystem as well as the account, or say plainly that it covers only
the account.


## Decision

**The portfolio is exactly `apps[]` in `tiara/tiara-data.json`. Registration is the only way in, and
a repo absent from it is out of scope, not a gap.**

1. A repo enters the portfolio one way: **New app** in Tiara, or the factory `newapp <Name>` script,
   which registers it as part of standing it up. There is no second route and no automatic discovery
   from the account or from disk.
2. An unregistered repo is **not measured, not scored and not reported**. An agent must not add the
   factory layer to it, must not report it as non-compliant, and must not file a ticket about its
   absence from Compliance. Absence from the registry is the answer, not a symptom.
3. The **permanent exclusions** are named here, because they are the ones that get re-argued:
   `Loop`, `cgm-remote-monitor` and `xdripswift` are third-party software, and `xdripswift` is one of
   them despite what the API says. `dlpchecker` is archived. `tiara` holds the registry and cannot be
   an entry in it. `Threadmap` is out, decided by Princess on 2026-08-16. `Dailylog`, `Meds`,
   `CandyArcade` and `CandyCart` are out, decided by Princess on 2026-08-18.
4. `HelloDaddy` and `bootstrap_model` are
   **unclassified**, not excluded. They are out of scope today like any other unregistered repo, and
   they are listed so that "nobody has decided" stays visible rather than being absorbed into
   "excluded".

Amended 2026-08-18: Princess classified `Dailylog`, `Meds`, `CandyArcade` and
`CandyCart` as out. They move from clause 4 to clause 3. `HelloDaddy` and
`bootstrap_model` stay unclassified. The table in Context records what was measured when
this decision was written and is left as it was.

Membership of the portfolio is a decision, never an observation.

## Consequences

The claim stays prose, so nothing checks it. Two states remain indistinguishable from outside: a
repo deliberately left out, and an app that was meant to be registered and was forgotten. This
decision makes the first one legible and does nothing for the second.

The exclusion list in clause 3 will go stale as repos are added, and nothing fails when it does. It
is accepted as the price of declaring the set rather than detecting it, because a heuristic that is
wrong once is worse than a list that is late.


## Alternatives considered

**A second GitHub account for the third-party forks.** The Definition of Done allows one if truly
necessary. It is not. It moves three repos at the cost of a second identity to authenticate, a
second place for tokens, and a permanent question about which account a new repo belongs in. The
registry answers the same question for nothing.

**Detecting the exclusions instead of declaring them.** `xdripswift` defeats the fork test and no
content test does better, because the third-party repos are real iOS apps with real Swift in them.
The one signal that works is the one the registry already carries.

**Making the exclusions data now**, as a `notOurs` list in `tiara-data.json` with a check that every
repo is registered, listed as not-ours, or newly appeared. Not rejected, deferred: see below. This
decision exists to end the argument, and that check is what would keep it ended.

**Leaving it undocumented.** The status quo, and the reason this keeps coming back. The code is right
and silent, and silence is what an agent fills in with a guess.

## Open, and deliberately not decided here

Whether this retires **There is one portfolio list and it is Tiara's (D48)**. It should, but
promoting a register row to an FD is itself proposed and undecided, at
`docs/decisions/proposed/FD-PROPOSED-a-decision-that-binds-every-repo-is-an-FD.md`. If this is
accepted first, D48 needs marking as promoted in the same commit, or there are two records of one
rule.

The six unclassified repos. This decision names them and classifies none of them.

The `notOurs` data and its check. The valuable state it would create is "newly appeared and awaiting
a decision", which turns an unclassified repo from invisible into a question.

`Threadmap`'s local clone has `origin` pointing at `alexbfree/Threadmap` for both fetch and push
while `Prinzaessin86/Threadmap` exists separately with no parent, so the working copy tracks a repo
Princess does not own. Found while checking this, filed separately, not a portfolio question.
