---
description: Why GitHub issues drift off a Projects board, and how boards are discovered. Loads when editing the board code.
paths:
  - "index.html"
---

# Boards and drift

Creating a GitHub issue does NOT add it to the app's Projects v2 board. An issue lands on
the board only if something explicitly adds it: **Tiara's own add-item flow** (`bAddItem`
creates the issue AND adds it) or the **one-time Linear→GitHub migration** (bulk-added once).
The boards have the reactive default workflows on (Item closed, PR merged, Auto-close) but
**NOT** the **"Auto-add to project"** workflow , so any issue created OUTSIDE Tiara
(`gh issue create`, the web UI, audit scripts, the factory, Claude Code/agents filing tickets)
never joins the board and goes invisible on the page. Signature: newest issues off-board,
migrated ones on-board.

- **Durable fix:** enable **"Auto-add to project"** on each board, filter `is:issue`, pointed
  at the app's repo (project → ⋯ → Workflows). This is **web-UI only** , GitHub exposes no
  API/`gh` path to configure Projects v2 workflows, so it can't be scripted.
- **Manual reconcile meanwhile:** diff repo issues vs board items (`gh issue list` vs
  `gh project item-list`), then `gh project item-add … --url <issue>` the missing ones and set
  Lane=Up next. Tiara defaults a missing Lane to "Up next" anyway.
- Every app is a LIVE board (linked Project + Lane/Priority/Type fields) , `discoverBoards`
  auto-detects any repo whose linked Project has a **Lane** field. `GH_BOARDS` hardcodes only
  PackMagic; the rest come through discovery. Registry lives in private `tiara/tiara-data.json`.
