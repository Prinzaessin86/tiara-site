---
name: session-sync
description: Keep the Tiara board honest at the end of a session. Use before finishing work that changed tickets, lanes or board data.
---

# Session sync

The board's truth is spread across this Mac, GitHub, the live page and the private
`tiara` doc, and a TestFlight bot pushes to GitHub every 6h , so this Mac drifts.
`scripts/tiara-sync.sh` is the single reconciler.

- **Start of every session, before touching the board:** run
  `bash scripts/tiara-sync.sh --auto` so you build on GitHub's latest.
- **End of every session, after your last commit:** run
  `bash scripts/tiara-sync.sh --auto` so nothing is left only on this Mac.
- If it reports a two-way split or uncommitted work it won't auto-resolve, run the
  interactive version and follow the prompts: `bash scripts/tiara-sync.sh`.

A background LaunchAgent (`com.princess.tiara.autosync`) also runs `--auto` every 30 min.
