# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/88
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/90
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/91
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/92
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/93

## CHANGED

`tiara-site`
- `index.html` — three shipped changes, `board-v89` → `board-v92`, one commit each.
- `.gate/finish-block.md` — this file.

`tiara` (private, committed locally, **not pushed**)
- `docs/HOW-TIARA-WORKS.md` — §4, §5 and §8, and `Describes: board-v92`.

Nothing else. No `.claude/`, no hook, no gate script, no `_bootstrap`, no `_ticketflow`, no
`issue-fields.psv`, no `ISSUE_FIELDS`.

## What changed

**[#91](https://github.com/Prinzaessin86/tiara-site/issues/91) timestamps → `board-v90`.** The page
never asked GitHub for a date at all. `loadBoardItems` now selects `createdAt`, `bLoadNotes` keeps
`created_at`, and one formatter and one CSS class put the filed date on the panel header and the
ticket page header and the posted date on every note. The date and time is the text; the relative
age is the hover, because an age changes every time you look. `fSort` now sorts by the real date
instead of by issue number, which was a proxy that is right inside one repo and wrong on Task queue.

**[#93](https://github.com/Prinzaessin86/tiara-site/issues/93) infra flag → `board-v91`.** The flag
half-existed: `kind:"infrastructure"` sat on three projects in `tiara-data.json`, the compliance
scanner already read `a.kind || 'app'`, and `index.html` wrote it nowhere and offered no control.
`normaliseApps()` now guarantees every project has one, `addApp()` asks, and the card ⋯ flips it. The
vocabulary is `app`/`infrastructure`, the scanner's, not the ticket's `product`/`infra` wording:
renaming would have meant changing `compliance.mjs` and `renderCompliance` in two repos for nothing.
No grouping, no colour, no filter axis — the ticket says this is the baseline, not the separation.

**[#92](https://github.com/Prinzaessin86/tiara-site/issues/92) edit tickets → `board-v92`.** Title,
body one `###` section at a time, and a note edited or deleted, all on the ticket page. The editors
are not in the row's detail panel because that panel is bounded on purpose (AD-0001 decision 4), and
`open full page ⤢` — already on all three row surfaces — is the route to them. Two things worth
naming:

- **A section is spliced, not rebuilt.** `bodySections` now returns each section's span in the raw
  body. Rebuilding the body from the parsed sections would renormalise the whitespace of six sections
  nobody edited, and the lane gate compares Acceptance byte-for-byte against the version a human last
  left. Proved: saving a section with the text it already had returns a byte-identical body, for
  every section including the last.
- **Editing Acceptance now says what it does.** Tiara writes as Princess, so an edit from here
  becomes the gate's new baseline. That is legitimate — a criterion is amended by a human,
  deliberately — and it was invisible. The editor prints it.

**[#88](https://github.com/Prinzaessin86/tiara-site/issues/88), answered.**
[comment](https://github.com/Prinzaessin86/tiara-site/issues/88#issuecomment-5277697268). Position:
**no second field.** A secondary deliverable has to be filled in at the moment nobody can fill it in
correctly — #85's answer proposed six tickets, #86's proposed three options of which two are not
being built, and #90 runs the other way round with the *decide* half unchecked. What is missing is
not a field but a moment: nothing ever asks "and then what?". Put that at the lane move for
`decision` and `investigation`, answer it with a real ticket or with "there is none", and record the
link in the board's already-existing, entirely unused `Parent issue`. One script, against four-plus
doors and thirteen form regenerations for the field. Questions 2–7 answered against the code.

**[#90](https://github.com/Prinzaessin86/tiara-site/issues/90), proposed, run 1 of 2.**
[comment](https://github.com/Prinzaessin86/tiara-site/issues/90#issuecomment-5277716106). Three
parts: mark the evidence the gate already derives and render it as evidence; a human sign-off as a
marked comment carrying the SHA-256 of the Acceptance it approved, written only by a new
`signoff.sh` that `guard-bash.sh` denies and `agent-comment.sh` refuses to carry; and the blocking
rule in the existing `pre-commit` and in the gate rather than in a post-commit hook, which cannot
block. **Not implemented** — its own Acceptance says run 1 is the proposal.

**Filed:** [#94](https://github.com/Prinzaessin86/tiara-site/issues/94), the three fields #92 left
out on purpose. Its body was corrected after filing (see below).

## The finding in the #90 proposal that stands on its own

**`tiara-site` has no `.claude/settings.json` and no `.claude/hooks/`, and by git it never has.**
`_bootstrap`, `_bootstrap/template` and `_ticketflow` each carry the whole set; this repo carries
none. So in this repo `guard-bash.sh` is not enforcing anything, and `verify-on-stop.sh` — the script
that requires this very file — is not installed. The finish blocks in `tiara-site/.gate/` are written
by convention. The two tracked files `.claude/.turn-dirty` and `.claude/.turn-start` are leftovers
from 31 July with nothing left that writes them.

That is step 0 of #90 and it is a human's change: `.claude/` is on the deny list everywhere else, and
an agent installing its own guard is the instruction `CLAUDE.md` says never to accept. I followed the
comment, ticket and board rules this session by choice, not because anything stopped me.

## A correction

I asserted in #94's body that the `bug` labels in this repo disagree with the board's `Type` field.
**That was wrong.** Measured: all 14 issues carrying a `bug`/`feature`/`chore` label agree with their
board `Type`. The real situation is redundancy, not contradiction — 78 of 92 issues carry no label
while every board item carries a Type. Corrected on the ticket through `agent-edit.sh`, so the
revision landed as the Bot and cannot become the criterion gate's baseline.

## Verified

`index.html` was driven in **jsdom against a fake GitHub**: **46 checks, 0 failures, no uncaught
errors**. Driver at
`/private/tmp/claude-501/-Users-CassandraMyers-Developer-tiara-site/5872574f-532f-4ed8-a6cd-7b382d839e77/scratchpad/drive.js`.
It covers:

- #91: the item carries its filed date; notes carry theirs; the date is on the panel header, the
  ticket page header and both notes; a bot note is still attributed to Claude Code; newest sorts by
  date not number, and falls back to number when there is no date.
- #93: every app ends with an explicit `kind`; the pre-existing `infrastructure` survives; the
  unflagged one becomes `app`; the kebab offers the flip; `setKind` flips both ways.
- #92: all three write paths reach the fake API; an empty title is refused; the edited section
  changes and **no other section does**; heading order is preserved; the Acceptance warning appears;
  a note edit keeps its prefix on GitHub and still strips it for display; a delete removes it; a
  forced 422 **reverts and says so**; an open editor defers the poll and stops deferring when closed
  or navigated away from.
- All five tabs, a project page and a ticket page render without throwing; a redraw mid-edit keeps
  unsaved text and does not touch the body.

`replaceSection` was additionally unit-checked against #91's real body and against a synthetic body
with a fenced `###` inside it: a no-op save is byte-identical for every section.

`python3 scripts/lint-tokens.py` green before each of the three commits, and the pre-commit hook ran
it on the staged content each time — it has no bypass.

## NOT VERIFIED

- **No screenshots. Nothing was opened in a real browser.** Three of four surfaces changed and I have
  no visual evidence for any of them. In particular I did not look at whether the `✎` next to the
  title, the six `✎` down the body and the two on each note read as a page or as clutter, and I did
  not check the new `.when` date against the row fill for contrast — it uses `--ink-3`, which the
  design system documents at 5.0:1, but I did not measure it in place.
- **No write against the real GitHub API was made from the page.** Every #92 save was exercised
  against a fake. #92's Deliverable is `manual` — "you will look at it yourself" — so the real-API
  half is deliberately yours, and it is the half that could still surprise us: I have not proved that
  GitHub accepts a `PATCH` of a body from this token, nor that editing an agent's Bot comment as
  Princess is permitted.
- **Not checked on a phone**, and the editors add a textarea and two buttons to a surface I have not
  seen at 375px.
- **`kind` has not been round-tripped through `ghSave`.** I read the code and confirmed the strip list
  does not delete it, but no save actually went to `tiara-data.json`, so I have not seen all 13
  projects come back with the flag written.
- **`compliance.mjs` was not re-run**, so `tiara_fields_match` is green by argument — `ISSUE_FIELDS`
  is untouched — and not by observation.
- **For #88:** nothing was built to see what breaks, so every cost in question 6 is read off the
  files. And I did not prove that `Parent issue` can be *written* by `gh`/GraphQL on a user-owned
  Projects v2 board, which the recommendation leans on. That is the one thing to check before
  building the rule.
- **For #90:** I did not check that a marker comment stays invisible everywhere a comment is rendered,
  I did not prove `agent-comment.sh` can refuse a `tiara:signoff` marker without also refusing the
  gate's own trace (which would carry the *evidence* marker through the same script), and I did not
  confirm `_bootstrap/template/.claude/` installs cleanly into a repo that is not a Swift app.

## Board

- [#88](https://github.com/Prinzaessin86/tiara-site/issues/88) → **Verify**, via
  `move-to-verify.sh`. `investigation`, and the answer is on the ticket.
- [#91](https://github.com/Prinzaessin86/tiara-site/issues/91),
  [#93](https://github.com/Prinzaessin86/tiara-site/issues/93),
  [#92](https://github.com/Prinzaessin86/tiara-site/issues/92) → **Verify**, via
  `move-to-verify.sh`. `code`/`manual`, each with a commit citing its full issue URL.
- [#90](https://github.com/Prinzaessin86/tiara-site/issues/90) → **left in Doing.** Its Acceptance
  says run 2 is the implementation. Moving it on the strength of a proposal would be the exact drift
  its own proposal is about.
- [#94](https://github.com/Prinzaessin86/tiara-site/issues/94) → **New.**

## Commits

`tiara-site`, on `main`:
- `board-v90: a ticket and a note say when they happened`
- `board-v91: a project says whether it is a product or infrastructure`
- `board-v92: a ticket's title, body and notes are editable on its own page`
- this finish block

`tiara`, on `main`: `Sync the Tiara doc to board-v92`.

**Not pushed by me.** `com.princess.tiara.autosync.plist` runs `tiara-sync.sh --auto` every 1800s and
pushes any local commit it finds, so the four `tiara-site` commits will reach GitHub without anyone
pressing anything.

**The doc commit will not.** `tiara-sync.sh` `cd`s into `tiara-site` and never leaves it, so its one
`git push` is that repo's only. So `docs/HOW-TIARA-WORKS.md` at `board-v92` is **on this Mac only**
until someone runs `git -C ~/Developer/tiara push`. The `doc-sync` skill's Contents-API recipe would
have put it straight on GitHub, and I did not use it: that is a push, and a push is not mine to make
unasked.
