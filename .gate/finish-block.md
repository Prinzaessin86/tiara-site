# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/75
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/76
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/77
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/78
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/79
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/80
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/81
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/82
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/83
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/84

## CHANGED

`tiara-site`
- `index.html` - nine changes, `board-v78` to `board-v87`, one commit each.
- `docs/decisions/AD-0001-…md` - moved out of `proposed/`, Accepted, carrying the nine tickets.
- `scripts/lint-tokens.py` - new. The design system's rule.
- `scripts/lint-tokens.README.md` - new. The hook patch, for a human to apply.
- `.gate/finish-block.md` - this file.

`tiara` (private)
- `docs/HOW-TIARA-WORKS.md` - a §3a for the filter bar, a §12 for the design system, and every
  control section rewritten. Stamped `board-v87`.
- `docs/ux-overhaul-mockup-board-v76.html` - the #75 mockup, pointed at the accepted decision.

## What changed

Nine tickets filed from AD-0001 and all nine built, in the order the decision says they must land.

- **#76 board-v78.** `onRowReorder` splices the moved item instead of rebuilding the queue from the
  rows in the DOM. This was a live crasher waiting for #84.
- **#77 board-v79.** 279 tokens in `:root`, every rule referencing one, at today's exact values.
- **#78 board-v80.** 39 font sizes to six, 25 radii to four.
- **#79 board-v81.** Every chip label onto its ink twin: 2.29:1–3.99:1 became 4.56:1–6.33:1.
- **#80 board-v82.** Priority and type are menus, and their setters call `bSetField` for the first
  time.
- **#81 board-v83.** `✕`/`title="delete"` and four unlabelled card controls into `⋯` menus with
  words; the row and card header wrap on a phone; every row control 48px on a coarse pointer.
- **#82 board-v84.** The row and its panel are one block with a rail; the panel names its ticket and
  shows Acceptance plus the newest note, stating what it is not showing.
- **#83 board-v86.** One filter bar on all three surfaces, with counts, removable chips, a URL, and
  a phone form. An absent Priority stops being invented as `med`.
- **#84 board-v85.** A Portfolio card shows ten and says so.
- **board-v87** deletes the lane counts the replaced chips fed.

## VERIFIED

- Both `<script>` blocks parse after every one of the ten commits.
- `scripts/lint-tokens.py` green, and proved by inducing one raw value of each kind in each of the
  three contexts it claims to cover.
- **#77 is pixel-identical, proved rather than asserted:** the stylesheet rendered against a fixed
  block of markup exercising every class, before and after, 2800×14000, byte-identical PNGs, same
  md5. The harness strips the webfont `@import` and freezes animations first, because a font that
  arrives over the network in one run and not the next, and a skeleton shimmer caught at a different
  phase, differ for reasons that have nothing to do with the change.
- 67 checks in node against the real functions, extracted from `index.html`: 9 reorder (including
  the capped and filtered cases, and the old function failing 6 of the 9), 21 chip menu and write
  path, 13 panel, 24 filter and URL.
- Contrast for all 13 chip labels computed on their own fills, not eyeballed.
- A real 375px viewport, inside an iframe, because headless Chrome will not size a window below
  500px: `scrollWidth` equals the viewport and no element exceeds it. With the coarse-pointer rules
  applied by hand, every row control measures 48.1px.
- Every surface rendered and looked at after the collapse (#78) and at the end.

## NOT VERIFIED

- **Nothing ran against a real GitHub board.** Every check is against the extracted functions with
  the network stubbed. The writes are asserted through `bSetField` being called with the right
  field and value, and reverting on rejection, not by watching GitHub change.
- **The lint rule is not wired into the gate.** `scripts/hooks/pre-commit` is a gate script and an
  agent may not edit one, even to make it stricter. The patch is written out in
  `scripts/lint-tokens.README.md` for you to apply. Until then it is a command, not a gate.
- **The kebab menu was not used with a keyboard or a screen reader.** `<summary>` is focusable and
  Escape is handled, but I have not tabbed through it.
- **The filter bar's URL was not tested in a browser**, only its serialise/parse round trip in node.
  Back/forward behaviour after `replaceState` is reasoned about, not observed.
- **Drag was not performed.** The reorder fix is proved against a fake DOM with standard SortableJS
  `onEnd` semantics assumed.
- No phone. Every phone claim is a measurement at a 375px viewport in a desktop browser.
- The mockup still describes decisions 1a/1b as one change and shows `.priochip2`; it is a record of
  the proposal, not of the build.

## Notes

Another session committed `board-v77` and a `#67` finish block in the same working tree while this
ran. No conflicts: they held `index.html` first, I took it afterwards.

**Nothing is pushed by me.** `com.princess.tiara.autosync.plist` pushes `tiara-site` every 30
minutes on its own and took `board-v76` and `board-v77` earlier today, so it will take these too.
No ticket was moved to Verify.
