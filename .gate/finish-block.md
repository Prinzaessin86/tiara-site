# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/56

## What changed

Two UX audits ran over the page, one on navigation and information architecture, one on task flow
and interaction. They were given different briefs and converged on the same root cause: the
redesign arc from board-v48 to board-v64 moved the editing controls onto one surface while moving
the clicks onto two others.

**Task queue rows carry status, priority and type.** `renderPortfolio` emitted a `priochip2` and a
`typechip2` as inert spans and no status control at all, so the tab named for working a queue was
the only surface a queue could not be worked from, and a row did not display its lane. It now
calls `chipSel(a.id,i,'status')`, `prioDot(a.id,i)` and `typeChip(a.id,i)` - the same three helpers
the Portfolio card row uses. No second implementation was added; the dead `pm`/`tm` locals are
gone.

**Project page rows carry the same three.** board-v51 turned a project name into a link to a
project page and stopped the click reaching the card `<summary>`, so the biggest click on a card
started landing on a page that deliberately had no controls. That decision is retired.

**`.priochip2` and `.typechip2` stop lying.** Both have carried `cursor:pointer` in the shared
stylesheet since they were written, while only the board attached a handler. Wiring the other two
surfaces makes the cursor true rather than deleting the affordance.

**`gotoBoardItem` and `refreshBoard` call `captureOpen()` first.** Without it the redraw rebuilt
every card from a stale `openState`, so jumping to an item silently shut every card that had been
opened by hand. Every other mutation path in the file already did this.

**Naming swept, labels kept.** You chose to keep Portfolio / Task queue, so the four places the
code contradicted the labels were fixed instead: the back link reads `← Portfolio`, the row and
sort tooltips say "in Portfolio", the Runbook heading reads "Tiara administration", and the two
stale comments were corrected. The tab labels and the tab ids still differ; §3 of the doc now
states the mapping outright.

**A Task queue row wraps below 640px.** The added dropdown pushed the chips off the side of a
phone. This is the file's first `@media` rule.

TIARA_VERSION bumped board-v64 to board-v65. `docs/HOW-TIARA-WORKS.md` in the private `tiara` repo
updated in this turn: §3 rewritten with the label-to-id table and the History tab removed, §4a
rewritten, §5 given a scope note, the lane order corrected to include `new`, and a board-v65
changelog section added.

Also delivered, in the private repo: `docs/usability-proposal-board-v65.html`, a clickable
prototype of the ten highest-value remaining changes. Proposal only, nothing in it is built.

## CHANGED

- index.html
- .gate/finish-block.md
- (private `tiara` repo) docs/HOW-TIARA-WORKS.md
- (private `tiara` repo) docs/usability-proposal-board-v65.html

## Proof

Headless Chrome against the real `index.html` with stubbed `data` and stubbed `bSetField` /
`bSetState`, so the write path is exercised without touching GitHub. 36 assertions, 36 pass:

- Task queue: 3 open rows from 4 items, status dropdown present and showing the item's own lane
  (`doing`), priority and type chips carry handlers, title still jumps, caret and issue link intact.
- Changing status from the Task queue: model updated to `verify`, `lane=Verify` written, list
  redrew with the new value. Priority cycled high to med with `priority=Med` written. Type cycled
  feature to chore with `type=Chore` written. Moving an item to done drops it off the open list,
  3 rows to 2.
- Project page: status dropdown, priority and type all present and wired, caret survived, back link
  reads `← Portfolio`, a status change wrote `lane=Blocked`, the page stayed open and redrew with
  the new value, and a Done row carries the controls too.
- Portfolio card unchanged: dropdown, grip and ✕ all still there.
- `gotoBoardItem` with both cards opened by hand leaves both open.
- Naming assertions read the real elements rather than the page text.

Both inline `<script>` blocks parse (`vm.Script`).

Screenshots in scratchpad: `taskqueue.png` (1000px, rows on one line, caret in place),
`project.png` (project page rows with priority, status and type), `taskqueue-phone.png` (390px,
rows wrapping to two lines). `taskqueue-phone-before.png` is the same viewport before the change,
for comparison.

Prototype: all 10 panels render on both Before and After without throwing; the search box narrows
14 rows to 1, the lane chip shows 3, a group heading collapses, and panel 7 demonstrates the note
box surviving in After and being wiped in Before.

## Not checked

- Not opened in your real browser against your real GitHub token. Every run used stubbed `data`
  and stubbed writes, so no status change has been watched reaching a real issue from the Task
  queue or a project page. The helpers are the board's, unchanged, but I have not seen it land.
- Not checked on a real phone. The 390px evidence is a headless viewport.
- The rest of the page still has no media queries. The tab strip and the header still run off the
  side of a 390px screen; only the Task queue row was fixed. Proposal 10 covers the rest.
- Auto sort re-sorts on every render, so cycling a priority from the Task queue moves the row
  under your finger. Status changes do not move it, since lane is not a sort key. Left as is;
  proposal 2 addresses it.
- `docs/HOW-TIARA-WORKS.md` is still stale in places I did not touch: §2 and §6 describe the
  roadmap.md sync path deleted in board-v45, §4 and §5 mention the Scramble lane removed in the
  same version, and §8 lists `inbox`, `scramble` and `done` in the data model while `ghSave`
  strips all three. Not in this ticket's scope, not filed.
- `.dots` remains roughly 2.3:1 against its background and still fails the squint test. Pre-existing
  and shared by all three surfaces. Not filed.
- Not pushed. Both repos are committed locally only.
