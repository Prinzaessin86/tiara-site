# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/95
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/85

## CHANGED

`tiara-site`
- `index.html` — the v2 redesign, `board-v92` → `board-v98`, six commits.
- `.gate/finish-block.md` — this file.

`tiara` (private, committed locally, **not pushed**)
- `docs/HOW-TIARA-WORKS.md` — §4, §5, §6, §8, and `Describes: board-v98`.
- `docs/UAT-tiara-board-v2.md` — new, the acceptance test.

Nothing else. No `.claude/`, no hook, no gate script, no `_bootstrap`, no `_ticketflow`, no
`ISSUE_FIELDS`.

## What changed

The approved *Tiara Board v2* mockup, built in six ordered slices, in the brief's own priority order.
Each has its own version bump and could have been the last one.

| | | |
|---|---|---|
| `board-v93` | the scale | type retuned to the design's 12/13/15/17/21/27px, root fixed at 16px, radii from 4 steps to a 2px ladder, one colour token |
| `board-v94` | the row | three visible groups, every value naming itself, words on every action, one row on three surfaces |
| `board-v95` | finding | a jump box taking `212` / `TIA#88` / title words, and a project search that offers the match elsewhere |
| `board-v96` | Done | month filter, per-page, real paging |
| `board-v97` | Portfolio | Apps and Infrastructure as two labelled groups |
| `board-v98` | open/closed, phone | one Show/Hide language everywhere, and the 375px pass |

**Filed first: [#95](https://github.com/Prinzaessin86/tiara-site/issues/95).**
[#85](https://github.com/Prinzaessin86/tiara-site/issues/85) cannot carry this build. Its
`Deliverable` is `decision: a proposal in docs/decisions/proposed`, and its own brief says *"Don't
write an ADR, a decision record, or a document in `docs/decisions/`."* The gate would look for a
file that will never exist. Splitting the build onto its own ticket is what
[#88](https://github.com/Prinzaessin86/tiara-site/issues/88) argues for, so this is its first use.
**#85 remains in Doing and is unmovable as written** — that is a board field and not an agent's.

## Decisions taken, and by whom

- **The type scale**: Princess chose to retune to the mockup rather than keep today's sizes, then
  confirmed the result at the live board (`board-v94` was deployed at the time): *"currently it
  reads rather big so keep it around the same"*, then *"size approved"*. The scale stands.
- **The radii**: match the mockup exactly, so seven values were added rather than rounded away.
- **Runbook ticks: not built**, on instruction — *"runbook doesn't need ticks at all"*. It was the
  one part of the design that added state rather than rearranging what exists.
- **Two controls the design draws are absent** and ticketed rather than shipped dead: *Move to
  another project…* (a GitHub issue transfer, which changes the number every board item points at)
  and *Send a build to TestFlight…*. Both are new capability, and the brief says this redesign is
  about how the board looks and reads, *"not what it does"*.
- **Knowledge and Compliance are not restyled**, named rather than skipped. Compliance already has
  the explain overlay and real per-check data where the mockup synthesises it, and neither tab is
  where the complaint came from.

## Three bugs found by the tests, not by reading

1. **The toggle handlers wrote the literal word `close`.** So even after the row builder was fixed,
   clicking a toggle put back the exact collision the brief asks to remove — one control away from
   `Close issue on GitHub`.
2. **They patched the panel and never touched the row**, so an in-place toggle left the row styled
   shut with its panel open. The open state only appeared after a full re-render.
3. **`scrollIntoView` was called unguarded** in the new keyboard handler. Not every element has it in
   every engine, and a keyboard handler that throws breaks navigation rather than failing to scroll.

## Verified

`index.html` driven in **jsdom against a fake GitHub**: **127 checks, 0 failures, no uncaught
errors**. Driver at
`/private/tmp/claude-501/-Users-CassandraMyers-Developer-tiara-site/5872574f-532f-4ed8-a6cd-7b382d839e77/scratchpad/drive.js`.
The fixture was rebuilt partway through to serve **two different boards** rather than the same one
twice — otherwise "found in another project" was testing against itself.

It asserts, among the rest: all three surfaces use the shared row and each has the capsule, all
three value names, three live selects and words on its actions; the destructive action is named and
marked danger; toggling flips both the word and the row's open state; the jump box handles a bare
number, `#n`, an id, title words and a project name, plus arrow keys, Escape, opening and clearing;
the project empty state names what it searched and offers the match elsewhere; the Done pager's
default size, remainder page, both edges disabling, *all of them*, the month filter and the clamp
when filtering while deep in the pages; both Portfolio groups exist, are named, explain themselves,
move a card between them and drop an emptied group; and every disclosure carries a Show/Hide word.

`python3 scripts/lint-tokens.py` green before every one of the six commits — the pre-commit hook
runs it on the staged content and has no bypass.

## NOT VERIFIED

- **Nothing was opened in a browser, at any point.** The Chrome tools were declined this session, so
  there are **no screenshots**, before or after, for a redesign that changes every surface. Every
  visual claim in the six commit messages is computed from the tokens, not observed.
- **No measured contrast.** AD-0001 sets the bar at 4.5:1 and no new label was held to it. The new
  small text is `--ink-3`, documented at 5.0:1, but that is the token's stated figure and not a
  measurement against the real fill.
- **The phone is written and never seen.** Slice 6's media queries are asserted to *exist*; nobody
  has held a phone. This is the single most likely thing to be wrong, and the row now carries more
  controls than the one it replaced.
- **No real GitHub write from the rebuilt row.** The value menus go through the same setters, which
  are unchanged, but no write has been watched reaching the board since the row was rebuilt.
  Section 2 of the UAT is the check that proves it, and it is Princess's to run.
- **`--r-sm/md/lg` were rem and are now px.** They shrank as well as the type (at 1280px `--r-lg`
  rendered 20.2px, now 14px). That was not separately reviewed.
- The Done month is **filed date, not closed date**, because the page does not fetch `closedAt`.
  Stated in the code, the commit, the doc and the UAT; not fixed.

## Board

- [#95](https://github.com/Prinzaessin86/tiara-site/issues/95) → **left in New.** Not moved to
  Verify. Its Acceptance is judged by looking at the real page, on a phone as well as a desktop, and
  none of that has happened. Moving it on a green script would be claiming a check that was not run.
- [#85](https://github.com/Prinzaessin86/tiara-site/issues/85) → **Doing, still unmovable.** Its
  Deliverable names a decision document that the brief forbids. Princess's to close or to amend.

## Commits

`tiara-site`, on `main`: `board-v93` … `board-v98`, plus this finish block.
`tiara`, on `main`: the UAT, its extension, and the doc sync to `board-v98`.

**Not pushed by me** (FD-0014). `tiara-sync.sh --auto` pushes `tiara-site` every 1800s and will
carry the six commits; it `cd`s into `tiara-site` and never leaves, so **the private `tiara` repo
will not be pushed** — `git -C ~/Developer/tiara push` when you want the doc and the UAT off this
Mac.
