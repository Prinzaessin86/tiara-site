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

## Other conventions
- `render()` must never throw — guard everything (a broken render blanks the board).
- Commit per meaningful change with a clear message; the git log is the source of truth.
- Bump `board-vNN` on every shipped change so the footer tells the truth about what's live.
