# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/57

## What changed

Nine of the ten items in the usability proposal, built. Proposal 3, "stop inventing a priority
nobody set", was not wanted and is not built: a missing GitHub Priority still reads as Med.

The stated constraint was that the page's type scale does not change and nothing comes across at
the prototype's smaller size. Every new control reuses a class that was already on the page:
`.pjq` (0.9rem) for the search box, `.pjlane` (0.8rem) for the filter chips, `.tb` (38px, 0.85rem)
for buttons, `.psortbtn` for the toggles. This is asserted, not assumed - see Proof.

**Task queue: search, chips, grouping, paging.** Search over title, id and project name; lane
chips and project chips each stating the count clicking them would give; a Clear filter button;
a View toggle between grouped-by-lane and a flat 25-per-page list. Built on `_tqView` mirroring the
project page's `_pjView`, with `tqSearch`/`tqLane`/`tqApp`/`tqPage`/`tqClear` mirroring its
functions. Filters reset on load; grouping and collapsed lanes persist, because a group heading
states its own count so a collapsed lane is never a silent truncation.

**A URL per surface.** `#/portfolio`, `#/queue`, `#/runbook`, `#/knowledge`, `#/compliance`,
`#/project/<id>`. The leading slash is load-bearing: the pane divs are called `#portfolio`,
`#runbook`, `#knowledge` and `#compliance`, so a bare `#portfolio` is a real fragment target and
the browser scrolled the page to that element. I hit exactly that and the screenshots caught it.

**State persists.** `openState`, `collapsed` and a per-surface scroll offset go to localStorage
alongside the existing sort key.

**Back path and breadcrumb.** The jump leaves a `← back to Task queue · item N of M` chip that
restores the surface and the offset. A project page reads `← Portfolio / <name>` and keeps the
Portfolio tab lit.

**Feedback where you are looking.** `.bar` is sticky. A row is dimmed while its write is in
flight, tinted on success via the existing `tiaraFlash` keyframe, and left visibly failed on
rejection. The two-write desync is fixed: a lane write that succeeds followed by a close that
fails now says the lane saved and the issue did not close, instead of reverting locally and
reporting "didn't save" while GitHub kept the change.

**One row, not the whole page.** `boardRowHtml` and `pjRowHtml` were lifted out of `render()` and
`renderProject()` so a single row can be rebuilt in place on every surface it appears on.
`afterEdit` redraws a surface only if that surface is actually wrong. The two-minute poll defers
its redraw while you are typing and runs it on blur; `renderProjectIfOpen`'s guard widened from
`#pjq` to any focused input in the pane.

**Refresh is back in the toolbar** and the freshness strip is the button; it leaves Runbook.

**Three states, not two.** `_loading` drives skeleton rows, so the page stops printing "every
board is clear 🎉" over data it has not read.

**Phone.** The toolbar, status line and chips wrap; chip and caret targets grow under
`@media (pointer:coarse)`.

TIARA_VERSION bumped board-v65 to board-v66. `docs/HOW-TIARA-WORKS.md` in the private `tiara` repo
updated in this turn: §3's Task queue bullet rewritten, and a board-v66 changelog section added.

## CHANGED

- index.html
- .gate/finish-block.md
- (private `tiara` repo) docs/HOW-TIARA-WORKS.md

## Proof

Two headless Chrome suites against the real `index.html` with stub data and stubbed `bSetField` /
`bSetState`, so the write path runs without touching GitHub. **56 + 37 = 93 assertions, all pass.**

New suite (56), covering: grouped default and five lane headings each stating a count; 30 rows
render; search narrows 30 to 3 and the head says "3 of 30"; a lane chip filters to exactly its own
stated count; a project chip filters to 10; collapsing a lane hides its rows, still states the
count, and persists to localStorage; flat mode pages 25 with "showing 1 to 25 of 30" and page 2
holding the remaining 5; the row goes busy in flight, writes the lane, then flashes; a type change
does NOT rebuild the Task queue (a canary node survives) while a status change does; a background
redraw is deferred while a box has focus; the two-write failure reports "saved, but the issue did
not close"; the three hash routes; a hash change navigates; the Portfolio tab stays lit on a
project page and the breadcrumb names it; expanded cards and scroll reach localStorage; the back
chip appears, names the position, expands the target card, and returns; freshness is a button that
calls refreshBoard and Runbook no longer holds a second one; `.bar` computes to `position: sticky`;
skeletons appear while loading and the celebration appears only when genuinely empty.

Sizing, asserted from computed styles: the Task queue search box is 17.60px, byte-identical to the
project page's `.pjq`; filter chips 15.65px; a lane heading 18.58px; the row title unchanged at
16.82px; and the smallest font on the whole tab is 15.26px.

Existing v65 suite (37) re-run as a regression check, after being made order-independent - it had
been finding rows by position, which grouping invalidated.

Two bugs I introduced and fixed during this work, both caught by screenshots rather than by the
assertions I had written first: the bare `#portfolio` hash scrolling the page to the Task queue
div, and `showTab`'s new `captureOpen()` wiping the card expansion `gotoBoardItem` had just set.
Both now have assertions.

Screenshots in scratchpad: `v66-taskqueue.png` (grouped, with tools), `v66-project.png`
(breadcrumb, controls), `v66-jumped.png` (back chip, target card expanded), `v66-loading.png`
(skeletons), `v66-phone-real.png` (a true 390px viewport).

Both inline `<script>` blocks parse (`vm.Script`).

## Correction to the board-v65 proof

The phone evidence in the previous finish block was measured wrongly. Headless Chrome clamps its
viewport to a 500px minimum, so `--window-size=390` produced a 390-wide **crop of a 500-wide
layout**, and `taskqueue-phone-before.png` / `taskqueue-phone.png` both show content running off
the right edge that was an artefact of that crop, not a real overflow. The v65 wrap rule was still
correct, and the rows do wrap at 390, but the before/after comparison I drew from those images was
not evidence. This turn measures inside a 390px iframe instead: `innerWidth=390`,
`docScrollWidth=390`, overflow 0px.

## Not checked

- Not opened in your real browser against your real GitHub token. Every assertion above ran
  against stub data with stubbed writes, so no status change has been watched reaching a real
  issue, and `loadFromGitHub` under the new `_loading` flag has not run against the real API.
- Not checked on a real phone. The 390px evidence is an iframe in a desktop browser.
- **Drag-to-reorder is not exercised.** `patchItemRow` replaces a `.qitem` via `outerHTML` inside
  the `.qlist` that SortableJS is bound to. It reads its children at drag time so this should be
  fine, but I have not dragged a row after patching one.
- The back chip is not restored across a reload. `_navFrom` is in memory only; the surface and
  scroll are persisted, the chip is not.
- Auto sort still moves a row when you cycle its priority, since priority is the sort key. That is
  the sort doing its job, and proposal 2's grouped view is the way around it.
- `docs/HOW-TIARA-WORKS.md` remains stale in §2, §6 and §8 (roadmap.md, Scramble, the data model),
  all of which predate this work. Not in scope, not filed.
- `.dots` is still roughly 2.3:1 and fails the squint test on all three surfaces. Not filed.
- Not pushed. Both repos are committed locally only.
