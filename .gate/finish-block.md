# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/85
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/86
TICKET: https://github.com/Prinzaessin86/tiara-site/issues/89

## CHANGED

`tiara-site`
- `docs/decisions/proposed/AD-0002-a-symbol-is-a-promise.md` — **deleted**, on instruction. Never committed, so it leaves no trace in git and cannot be recovered.
- `docs/decisions/proposed/` — removed, now empty.
- `.gate/finish-block.md` — this file.

`tiara` (private)
- `docs/AD-0002-a-symbol-is-a-promise.pdf` — **deleted**. Same document, same instruction. Also
  never committed, also unrecoverable.
- `docs/symbol-density-prototype-board-v89.html` — kept, still uncommitted. It is a mockup, not an
  ADR, and #85 asked for it by name.

`index.html` was NOT touched at any point this session. No `TIARA_VERSION` bump, no `doc-sync`.

## What changed

**The ADR is gone.** Deleted on instruction: an ADR was not what was wanted here. Both file forms of
AD-0002 are removed. The reasoning behind it is not lost: the whole of it is on the ticket at
[#85 (comment)](https://github.com/Prinzaessin86/tiara-site/issues/85#issuecomment-5267192725),
which is where the findings, the measurements and the six proposed changes are written out.

Committed this turn: only `.gate/finish-block.md`. Deleting an untracked file stages nothing, so
there is no deletion to commit.

**Filed earlier this session:** [#89](https://github.com/Prinzaessin86/tiara-site/issues/89), Chore,
Lane New, Priority Med, `Deliverable: code`. Option 1 of the three stacks in #86: serve `index.html`
from private hosting behind a proxy that holds the credential. The token work is explicitly out of
its scope, because it is already [#47](https://github.com/Prinzaessin86/tiara-site/issues/47) and
[#62](https://github.com/Prinzaessin86/tiara-site/issues/62).

## Board

- [#86](https://github.com/Prinzaessin86/tiara-site/issues/86) → **Verify**. Investigation answered
  on the ticket, plus a comment pointing at #89.
- [#89](https://github.com/Prinzaessin86/tiara-site/issues/89) → **New**.
- [#85](https://github.com/Prinzaessin86/tiara-site/issues/85) → **Todo, and now unmovable as
  written.** Its `Deliverable` field says `decision: a proposal in docs/decisions/proposed`, and the
  gate checks for exactly that. There is no longer a decision document and there is not going to be
  one, so the ticket cannot reach Verify until its Deliverable is changed. That is a board field, so
  it is not an agent's to change. Flagged, not worked around.

## Commit

`gate: the AD-0002 decision deleted, and the finish block for #85, #86 and #89`, on `main`, in
`tiara-site` only.

Not pushed by me. `com.princess.tiara.autosync.plist` is loaded and runs `tiara-sync.sh --auto`
every 1800s, which pushes any local commit it finds, so this will reach GitHub within half an hour
without anyone pressing anything. The commit was asked for.

`tiara` was left uncommitted. The prototype there is still uncommitted, and still exists only on this Mac.

## What I did not check

I did not verify the prototype still opens after the two deletions. It is one self-contained file and
references neither deleted file, but it was not re-rendered after the fact.

I did not change #85's `Deliverable` field, and I did not check whether the gate offers a way to
retire a ticket whose deliverable no longer applies.

**Carried, unchanged.** Nothing this session was verified against the live board in a browser. The
counts, the token audit, the control inventory and the glyph census were read out of `index.html` by
script and are exact; the pixel sizes were computed from the clamp, not measured on Tiara. The two
density percentages were measured on the prototype, not on a real Portfolio card. For #89: no
private host was chosen or priced, so "days" is effort and not calendar, and I did not prove by
attempt that `ghGraphQL` and the `ghApi` helper are the whole page-side change.
