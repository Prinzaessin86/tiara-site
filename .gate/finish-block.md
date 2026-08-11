# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/74
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/75

## CHANGED

`tiara-site`
- `index.html` - the markdown renderer, the `.md` styles, the note markup, `TIARA_VERSION` to
  `board-v76`. Committed as `6aefb4e`.
- `docs/decisions/proposed/AD-0001-one-type-scale-one-control-vocabulary-one-filter-bar.md` - new,
  uncommitted. The #75 proposal.
- `.gate/finish-block.md` - this file.

`tiara` (private)
- `docs/HOW-TIARA-WORKS.md` - bodies and notes render as markdown; `Describes:` moved to
  `board-v76`. Committed as `efa172f`.
- `docs/ux-overhaul-mockup-board-v76.html` - new, uncommitted. The #75 mockup.

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

**#75, in progress.** The proposal and the mockup are written; the subagent review the ticket asks
for is still running, and both documents carry a *pending* review section until it lands.

## VERIFIED

- `node --check` on both `<script>` blocks of `index.html`: parse clean.
- The renderer, extracted and run under node against 18 cases: headings, nested lists, loose lists,
  task boxes, fenced blocks, tables, quotes, links, bare URLs, rules, hard-wrapped bullets, a
  hard break, empty input and `null`. All render as intended, none throws.
- XSS: `<img src=x onerror=…>`, `<script>` and `[click](javascript:alert(1))` all come out inert.
  Asserted, not eyeballed: no raw `<img`, no raw `<script`, no `href="javascript`.
- Device proof, one real agent comment (tiara-site#70's last comment, which has headings, a
  twelve-row table, bold, code spans, bullets and a link) rendered before and after, screenshotted
  in Chrome: `scratchpad/proof-74.png`. The issue body of #75 before and after:
  `scratchpad/proof-74-body.png`. The #75 mockup: `scratchpad/mockup-top.png`,
  `mockup-row.png`, `mockup-tail.png`.
- The pre-commit doc checkpoint passed on the version bump.

## NOT VERIFIED

- Nothing was run in the real page against real GitHub data. The proof pages use the file's own CSS
  and the exact functions from `index.html`, extracted, not the live board.
- No phone. The renderer was not looked at below 640px, and neither was the note card.
- Every count in the #75 proposal (39 font sizes, 127 hex colours, 25 radii, 81 padding values) was
  measured from `index.html` by script. The "38 of 72 items with no priority" is quoted from a code
  comment and was not re-counted against the board.
- The #75 proposal is a proposal. None of it is built, and the staging order in it is an estimate.

## Notes

Another session was editing `index.html` in the same working tree for TIA-70. We split it: my
`board-v76` landed first, theirs went on top as `board-v77`.

Nothing is pushed. Both repos have unpushed commits.
