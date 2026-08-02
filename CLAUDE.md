# Tiara-site

The public GitHub Pages page for Tiara: a single static file, `index.html`, HTML and JS with no
backend. Board settings live in the separate private repo `Prinzaessin86/tiara`
(`tiara-data.json`). Each app's live queue is a GitHub Projects v2 board in that app's repo.

It is not an application and has no build, no tests and no Makefile.

## Conventions

- `render()` must never throw. Guard everything: a broken render blanks the board.
- Bump `const TIARA_VERSION = 'board-vNN'` on every shipped change, so the footer tells the truth
  about what is live.
- A material change to `index.html` means `docs/HOW-TIARA-WORKS.md` in the private repo is updated
  in the same turn. The doc must never lag the page. Use the `doc-sync` skill.

## Where else to look

| For | Look in |
|---|---|
| Updating the captured reference | `.claude/skills/doc-sync` |
| Ending a session honestly | `.claude/skills/session-sync` |
| Why issues drift off a board | `.claude/rules/boards.md` |
| What Tiara is, and every control | `docs/HOW-TIARA-WORKS.md`, private `tiara` repo |
| What happened | git and the board |
