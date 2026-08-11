# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/74
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/75

## CHANGED

`tiara-site`
- `index.html` - the markdown renderer, the `.md` styles, the note markup, `TIARA_VERSION` to
  `board-v76`. Commit `6aefb4e`.
- `docs/decisions/proposed/AD-0001-one-type-scale-one-control-vocabulary-one-filter-bar.md` - new.
  Commit `e9019da`.
- `.gate/finish-block.md` - this file.

`tiara` (private)
- `docs/HOW-TIARA-WORKS.md` - bodies and notes render as markdown; `Describes:` moved to
  `board-v76`. Commit `efa172f`.
- `docs/ux-overhaul-mockup-board-v76.html` - new, the #75 mockup. Commit `b123f04`.

## What changed

**#74, shipped.** An issue body and every comment on it arrive from GitHub as markdown and were
printed escaped inside `white-space:pre-wrap`, so a heading, a bullet, a bold lead-in and a
paragraph all landed at one size with no space between them. `mdHtml()` renders the subset these
boards write: headings, bold, italic, code, fenced blocks, nested bullet and numbered lists, task
boxes, tables, quotes, rules and links. A note's author moved onto its own line, because a bold
prefix cannot sit in front of text that starts with its own heading.

A single newline inside a paragraph became a space rather than a line break. Every comment here is
hard-wrapped near 100 characters and a detail panel is far narrower, so honouring those newlines the
way GitHub does broke each paragraph into ragged half-lines. Two trailing spaces still force a break.

**#75, proposed.** A decision and a mockup, neither built. Eight ordered changes: fix `onRowReorder`
first, then tokens twice (once at today's exact values, once as the collapse), labels onto the ink
twins, `chipSel` for priority and type plus the write path they are missing, `⋯` for the destructive
actions and the phone rules, a bounded panel that names its ticket, one filter bar with a URL, and a
capped Portfolio card last.

The subagent review the ticket's acceptance requires ran against the draft and `index.html`, and
returned twelve findings. Four named defects in the code this design would have walked into, and all
four were re-verified here line by line before being accepted: the card cap would have made
`onRowReorder` write `undefined` into the queue and `render()` throw; an absent Priority is coerced
to `med` twice on the way in, so "untriaged" is not representable without a data-model change;
`chipSel` already handles priority and type but its setters never call `bSetField`, so adopting it
as-is would silently stop writing to GitHub; and four claims of fact in my draft were wrong,
including the nesting depth and the hex count. All twelve are recorded with their verdicts in both
documents.

## VERIFIED

- `node --check` on both `<script>` blocks of `index.html`: parse clean.
- The renderer, extracted and run under node against 18 cases: headings, nested lists, loose lists,
  task boxes, fenced blocks, a fence inside a bullet, tables, quotes, links, bare URLs, rules,
  hard-wrapped bullets, a hard break, a list followed by a heading, empty input and `null`. All
  render as intended, none throws.
- XSS asserted, not eyeballed: `<img src=x onerror=…>`, `<script>` and `[click](javascript:…)` all
  come out inert - no raw `<img`, no raw `<script`, no `href="javascript`.
- Device proof for #74: one real agent comment (tiara-site#70's last, with headings, a twelve-row
  table, bold, code spans, bullets and a link) rendered before and after, and the issue body of #75
  before and after, screenshotted in Chrome. `scratchpad/proof-74.png`, `proof-74-body.png`.
- Device proof for #75: the mockup rendered at 1300px, `scratchpad/mockup-top.png`,
  `mockup-row.png`, `mockup-tail.png`, `mockup-rev.png`.
- Every count in the proposal measured by script against `index.html`: 39 font sizes, 123 hex
  colours in `<style>` (128 in the file), 25 radii, 81 padding values. Contrast ratios computed from
  the `PRIO_META` / `STATUS_META` / `TYPE_META` colours against the row fill, not taken from the
  review.
- The four code defects the review reported, each read at its line: `onRowReorder` at `:1601`,
  the priority coercion at `:903` and `:1632`, `setPrio`/`setType` at `:1779-1791`, and
  `--r-md`/`--r-lg` absent from `:root`.
- The pre-commit doc checkpoint passed on the version bump.

## NOT VERIFIED

- Nothing ran in the real page against real GitHub data. The #74 proof uses the file's own CSS and
  the exact functions from `index.html`, extracted, not the live board.
- No phone. Neither the renderer nor the note card was looked at below 640px.
- The review's live board counts (46 items with no priority, 21 with no type, three boards over 30
  open) were not re-counted. The proposal quotes the "three boards over 30" figure and says whose it
  is; it does not quote the others.
- The #75 proposal is a proposal. None of it is built, and the sizes in its shipping table are
  estimates.
- The mockup was not opened on a phone-width viewport in a browser; its 375px panel is a fixed-width
  mock, not a responsive test.

## Notes

Another session was editing `index.html` in the same working tree for TIA-70. We split it by
message: my `board-v76` landed first, theirs went on top as `board-v77`.

**I pushed nothing, and #74 is live anyway.** `com.princess.tiara.autosync.plist` runs
`tiara-sync.sh --auto` every 30 minutes and pushes `tiara-site` when it is ahead. It took `6aefb4e`
(board-v76) and the other session's `c175ecf` (board-v77) at 11:20, so the markdown renderer is on
the public page now. Still local at the time of writing: `tiara-site` `e9019da` and `2b70b6f` (the
proposal and this file), and `tiara` `efa172f`, `6e034ba`, `b123f04`. The same agent will take them.
The private repo is also one commit behind its remote, a scheduled TestFlight-status write.

Neither ticket was moved to Verify. #74 is on the page and could be, but moving a ticket is a write
to the board and was not asked for; #75 is a proposal waiting on approval, which is the one thing
"verify" cannot mean.
