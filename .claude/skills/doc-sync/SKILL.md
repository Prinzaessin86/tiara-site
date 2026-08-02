---
name: doc-sync
description: Update HOW-TIARA-WORKS.md in the private tiara repo after any material change to index.html, and bump the board version. Use whenever a tab, control, row action, sync behaviour, badge or health check changes.
---

# Doc sync

The captured reference **`docs/HOW-TIARA-WORKS.md` lives in the PRIVATE `tiara` repo**,
never on this public page. It documents what Tiara is + every control.

Whenever you make a **material** change to `index.html` , a new/changed tab, card control,
row action, sync behavior, badge, or health checkmark:

1. **Bump** `const TIARA_VERSION = 'board-vNN'` (the footer reads it).
2. **Update** `docs/HOW-TIARA-WORKS.md` in the private `tiara` repo so it matches , the
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
