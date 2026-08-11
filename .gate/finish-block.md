# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/50
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/69
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/71
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/72
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/73
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/77

## CHANGED

`tiara-site`
- `index.html` — `board-v88`. Four tickets in one commit, `0fef4ef`.
- `.gate/finish-block.md` — this file.

`tiara` (private)
- `docs/HOW-TIARA-WORKS.md` — Runbook, Compliance and "Filing an item" rewritten. Stamped
  `board-v88`. Commit `40cb983`.

`_bootstrap`
- `template/idget |bug|` — deleted. Commit `7221964`.

## What changed

- **#50.** A read-only `xcc get-trigger` step in the TestFlight recipe, after onboarding, and the
  failure step's "NO runs ever fired" line repointed at it. `--strict` named.
- **#69.** Both add-issue doors open one full-width page at `#/new/<appId>`: project, type,
  priority, title, and every field of the chosen type. The toolbar strip and the card's fold-out
  compose panel are deleted, along with `aiTypeChange`, `aiVals`, `composeHtml`, `draftType`,
  `addItem` and `draftBody`. The shared `_drafts` store survives.
- **#71.** A compliance explanation opens as an overlay on `<body>` instead of a `<details>` in a
  grid column. `.ccol:has(.cchkx[open]){grid-column:1/-1}` is gone, which is what moved the page.
  No body-scroll lock, deliberately: `overflow:hidden` takes the scrollbar and shifts the page.
- **#72.** The Runbook renders each product's real workflows from `compliance.json`. Four answers:
  Actions linked, Xcode Cloud named-never-linked, `[]` as an explicit none, `null` as unknown.
- **#73.** The stray template file is deleted, in `_bootstrap`.

## VERIFIED

- Both `<script>` blocks parse (`node --check`) after every edit.
- `python3 scripts/lint-tokens.py index.html` green, and **proved not vacuous**: an induced
  `color:#ff00aa`, `font-size:13px` and `border-radius:7px` in one rule outside `:root` are all
  three reported, `rc=1`, on a copy of today's file.
- **#71 measured, not eyeballed.** In headless Chrome, the first compliance row's
  `getBoundingClientRect` is byte-identical before and after opening an explanation
  (`{"x":110,"y":666.671875,…}` both times), as are `window.scrollY` and
  `document.documentElement.clientWidth`, with the overlay present.
- **#72 checked against a mutated scan**, because the live one contains none of the interesting
  cases: `xcodeCloud:null` renders "unknown, no App Store Connect key at scan time"; a record with
  the whole `workflows` key deleted renders "not scanned for workflows" and does not throw;
  `missing:true` says nothing could be checked; two injected Actions entries render as links with
  the scanner's own URLs; zero Xcode Cloud chips are anchors.
- **#69, thirteen assertions in the real page**: the card's type menu opens the page with that
  project, type and typed title; all seven bug fields render; the board is hidden; submit refuses
  while a required field is empty and names it; a half-typed field survives `render()`; the toolbar
  door opens the same page; switching project keeps each project's draft apart; the route is
  `#/new/<id>`.
- Screenshots of Runbook, the overlay, the filing page empty and with a type chosen, and the card
  queue box.
- Board data and `compliance.json` are the real files, injected into an offline copy of
  `index.html`, because the live page needs a GitHub token for both.

## NOT VERIFIED

- **Nothing ran against a real GitHub board.** No issue was actually created through the new page;
  `bAddItem` is unchanged and was not called. The create path is asserted only as far as the
  refusal, the body it builds and the optimistic row.
- **No real browser session.** Every check is headless Chrome against an offline harness with
  stubbed board data. Not clicked by hand, no phone, no keyboard or screen-reader pass over the new
  page or the overlay. The overlay's Escape handler and backdrop click are written, not exercised.
- **#77's remaining half is not done and will not be by me.** `scripts/hooks/pre-commit` is a gate
  script, and the root `CLAUDE.md` says an agent never edits one, even to make it stricter. The
  patch is in `scripts/lint-tokens.README.md`. Until a human applies it the linter is a command you
  must remember to run. #77 stays where it was.
- **#73 could not be moved to Verify.** `move-to-verify.sh` refused it, correctly: its Deliverable
  is `code` and the gate looks for a citing commit in `~/Developer/tiara-site`, but the work is in
  `_bootstrap`. Reported on the ticket rather than worked around. A ticket filed on one board whose
  scope is another repo has no path through that gate.
- The acceptance for #73 names "the three template repos that already received it". Nobody says
  which three, so it was read as every repo under `~/Developer`; none has a file of that name.
- **#50's literal CHECK cannot pass.** It asks for `grep -c 'get-trigger' index.html >= 2`, but
  `grep -c` counts *lines* and the whole `SEED` runbook is line 932. There are two occurrences,
  both inside the `testflight` recipe as required (`grep -o … | wc -l` = 2); `grep -c` reads 1. No
  third mention was added elsewhere to satisfy the letter of it, since the ticket itself says a
  mention outside the recipe does not count.
- **No `workflows` link was rendered against live data**, because every app's `actions` array is
  currently empty. The link form is the scanner's own and was exercised only with injected entries,
  so "no link 404s" is untested rather than passing.
- Nothing pushed. Three commits sit local, in three repos.

## Notes

`_bootstrap/.gate/finish-block.md` held another session's uncommitted block. Mine is prepended and
theirs is kept below a divider rather than overwritten.
