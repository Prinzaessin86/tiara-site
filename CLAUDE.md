# Tiara-site — working rules

This repo is the **public** GitHub Pages page for Tiara: a single static file,
`index.html` (HTML + JS, no backend). Board settings live in the separate **private**
repo `Prinzaessin86/tiara` (`tiara-data.json`); each app's live queue is a GitHub
Projects v2 board in that app's repo.

## Doc-sync checkpoint (REQUIRED — this is the whole point of the hook)

The captured reference **`docs/HOW-TIARA-WORKS.md` lives in the PRIVATE `tiara` repo**,
never on this public page. It documents what Tiara is + every control.

Whenever you make a **material** change to `index.html` — a new/changed tab, card control,
row action, sync behavior, badge, or health checkmark:

1. **Bump** `const TIARA_VERSION = 'board-vNN'` (the footer reads it).
2. **Update** `docs/HOW-TIARA-WORKS.md` in the private `tiara` repo so it matches — the
   doc must never lag the page. Write it via the Contents API (needs the current sha):
   ```
   sha=$(gh api repos/Prinzaessin86/tiara/contents/docs/HOW-TIARA-WORKS.md --jq .sha)
   b64=$(base64 -i HOW-TIARA-WORKS.md | tr -d '\n')
   gh api repos/Prinzaessin86/tiara/contents/docs/HOW-TIARA-WORKS.md -X PUT \
     -f message="Sync Tiara doc to board-vNN" -f content="$b64" -f sha="$sha"
   ```

A pre-commit hook (`scripts/hooks/pre-commit`) enforces the version bump on any
`index.html` change and reminds about the doc. It's wired via `core.hooksPath`; on a
fresh clone, re-enable it once with:
```
git config core.hooksPath scripts/hooks
```
One-off bypass (e.g. a pure typo fix): `TIARA_SKIP_DOC=1 git commit …`.

## Why issues drift off a board (and the fix)

Creating a GitHub issue does NOT add it to the app's Projects v2 board. An issue lands on
the board only if something explicitly adds it: **Tiara's own add-item flow** (`bAddItem`
creates the issue AND adds it) or the **one-time Linear→GitHub migration** (bulk-added once).
The boards have the reactive default workflows on (Item closed, PR merged, Auto-close) but
**NOT** the **"Auto-add to project"** workflow — so any issue created OUTSIDE Tiara
(`gh issue create`, the web UI, audit scripts, the factory, Claude Code/agents filing tickets)
never joins the board and goes invisible on the page. Signature: newest issues off-board,
migrated ones on-board.

- **Durable fix:** enable **"Auto-add to project"** on each board, filter `is:issue`, pointed
  at the app's repo (project → ⋯ → Workflows). This is **web-UI only** — GitHub exposes no
  API/`gh` path to configure Projects v2 workflows, so it can't be scripted.
- **Manual reconcile meanwhile:** diff repo issues vs board items (`gh issue list` vs
  `gh project item-list`), then `gh project item-add … --url <issue>` the missing ones and set
  Lane=Up next. Tiara defaults a missing Lane to "Up next" anyway.
- Every app is a LIVE board (linked Project + Lane/Priority/Type fields) — `discoverBoards`
  auto-detects any repo whose linked Project has a **Lane** field. `GH_BOARDS` hardcodes only
  PackMagic; the rest come through discovery. Registry lives in private `tiara/tiara-data.json`.

## Other conventions
- `render()` must never throw — guard everything (a broken render blanks the board).
- Commit per meaningful change with a clear message; the git log is the source of truth.
- Bump `board-vNN` on every shipped change so the footer tells the truth about what's live.

## Session sync (keep the board honest)

The board's truth is spread across this Mac, GitHub, the live page and the private
`tiara` doc, and a TestFlight bot pushes to GitHub every 6h — so this Mac drifts.
`scripts/tiara-sync.sh` is the single reconciler.

- **Start of every session, before touching the board:** run
  `bash scripts/tiara-sync.sh --auto` so you build on GitHub's latest.
- **End of every session, after your last commit:** run
  `bash scripts/tiara-sync.sh --auto` so nothing is left only on this Mac.
- If it reports a two-way split or uncommitted work it won't auto-resolve, run the
  interactive version and follow the prompts: `bash scripts/tiara-sync.sh`.

A background LaunchAgent (`com.princess.tiara.autosync`) also runs `--auto` every 30 min.

## Work tracking (canonical rule)
Tiara tracks its **own** tasks the same way every app does: as **GitHub Issues** on its own Projects v2 board (`Tiara`, user project #11), linked to this repo. Never Linear (retired 2026-07-21), and never a file. **There is no queue file, inbox file or scratch file here or in any repo, and there must never be one.** (D39, D40, D41, D44). App tickets live as GitHub Issues in each app's own repo, on that app's board. Full rule: user-level `~/.claude/CLAUDE.md`.
