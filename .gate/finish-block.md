# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/54

## What changed

Project pages showed no item detail or notes. `renderProject` had its own row renderer that
emitted id, title, type chip and issue link and nothing else. The Board tab and the Portfolio tab
were never broken; both halves of the problem arrived in board-v51, which added project pages and
at the same time turned a project name into a link to one, so a familiar click started landing on
a page with inert rows.

Project page rows now carry the same caret and detail slot, reusing `detailHtml` / `dsId` through a
third scope (`j`), alongside the existing board (`''`) and portfolio (`'p'`) scopes. No second
detail implementation was added.

`render()` now ends with `renderProjectIfOpen()`. Without it a note added on a project page landed
in the data and appeared nowhere, because `render()` rebuilds the tabs only. It skips the redraw
while the search box has focus, so the two-minute background poll cannot eat what is being typed.

TIARA_VERSION bumped board-v63 to board-v64.
`docs/HOW-TIARA-WORKS.md` in the private `tiara` repo synced in this turn (new §4a, changelog
entries for v64 and the undocumented v63):
https://github.com/Prinzaessin86/tiara/commit/e483018a3d5f4b87ff7959ff2657b14a5cca4e49

## CHANGED

- index.html
- .gate/finish-block.md

## Proof

Headless Chrome against the real `index.html` with a stubbed `data`, twice.

Run 1, project page:
`carets=2 slot=yes hasNote=yes glyph=▾ noteInput=yes afterClose=empty afterRender=persists
doneCaret=yes boardSlotStillThere=yes`

Run 2, regressions and the round trip:
`boardCaret=yes boardDetail=yes boardNoteInput=yes noteAppears=yes stillOnProjectPage=block
searchSurvivesRender=yes`

Screenshot of a project page with a detail open, notes and the add-a-note box rendering, detail
sitting flush with its row: scratchpad `project-detail.png`.

Both inline `<script>` blocks parse (`vm.Script`).

## Not checked

- Not opened in your real browser against your real GitHub token. Every run above used stubbed
  `data`, so the GitHub read/write path for notes on a project page (`bLoadNotes`, `bComment`) is
  unexercised. The board path it copies is unchanged, but I have not watched a note reach a real
  issue from a project page.
- Not checked on a phone or a narrow viewport. The screenshot is 900px wide.
- `.dots` is `#b09bc9` on `#fdfaff`, roughly 2.3:1, which fails the squint test. That is the
  Board's existing caret styling and I reused it rather than diverge; fixing it changes every
  surface and is out of scope for this ticket. Not filed.
- Not pushed.
