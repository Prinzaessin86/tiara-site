# Finish block

TICKET: https://github.com/Prinzaessin86/tiara-site/issues/110

## CHANGED

`tiara-site` (committed `a788dcf`, **not pushed**)
- `index.html` — `board-v108` → `board-v109`. The compose form is read from the field definition.
- `.gate/finish-block.md` — this file.

`tiara` (private, committed locally `83dffe5`, **not pushed**)
- `docs/HOW-TIARA-WORKS.md` — the "New issue" section: how the fields are read, what happens when
  the definition is unreachable, and the controls a record can ask for.

Nothing else. No `.claude/`, no hook, no gate script, no `_bootstrap`, no `_ticketflow`.
The `CLAUDE.md`, `.factory-checksum` and `FD-0014-agents-do-not-push.md` changes already in the
working tree are a factory vendor pass, were there before this turn, and were left alone.

## What changed

`ISSUE_FIELDS` and the `DELIVERABLE` literal are deleted. The compose form is built from
`Prinzaessin86/_bootstrap/template/.github/issue-fields.psv`, fetched through the existing
`ghGetFile` helper — the canonical copy, not the one `vendor-factory.sh` ships into this repo.

The blocker the old comments named ("waits for the move off Pages") was checked and is not real:
no fetch in this page reads its own origin, so where it is served from never mattered.

- `parseIssueFields` handles `meta`, `field`, `dropdown`, `multiselect`.
- `checkboxes` and any unrecognised record kind **block that type** and say which field and why,
  rather than being skipped. A skipped field is a missing `### ` heading, and the two doors would
  stop agreeing on shape while both still looked fine. Other types still compose.
- No fallback list. Unreadable and uncached: the form refuses, names the error, offers a retry,
  draws no fields, disables **Create issue**. `submitNewIssue` refuses independently, because
  `missingFields` over an empty list reports nothing missing and would file an empty body.
- A cached copy is used and **announced**, with the date read, the age, and the live read's error.
- `multiselect` renders as removable chips, writing what GitHub writes.

## Proof

Two harnesses in the session scratchpad, both running the real code from `index.html`, not a copy:
`check.js` slices the functions out of the file and runs them against the real `.psv` (32
assertions); `dom.js` loads the whole page in jsdom with only the network stubbed and reads what it
draws (28 assertions). All 60 pass.

- adding a sixth `Deliverable` option to the definition makes it appear, with no edit to
  `index.html`; removing one removes it; a new `field` record appears in file order
- headings and required set identical to the generated `bug.yml`, `feature.yml`, `chore.yml`
- definition unreadable → no fields, no menu, disabled button, `submitNewIssue` refuses
- a `multiselect` record draws chips; `×` removes one; the body writes `### Repos` then the names
  comma-and-space separated on one line, in definition order
- `python3 scripts/lint-tokens.py index.html` green; pre-commit hook green

## Not checked

- **No browser screenshot.** Chrome tooling was unavailable this session. Everything visual is
  asserted in a real DOM, not looked at by a human. `preview.html` in the scratchpad drives the real
  page with `?case=multi|error|cache|blocked` if you want to open it.
- **Not exercised against the live API from a browser.** The parser was fed the real file from disk.
  `gh api` confirms the path serves 7,949 bytes, so the token needs read access to the private
  `_bootstrap` repo — the first compose after this ships is the real test.
- **Multiselect order is declared order, chosen, not proven.** The separator, the single line and
  `_No response_` are read off `davisking/dlib#3070`. One selection cannot distinguish declared
  order from click order, and dlib's last 100 issues held only one.
- The private doc still carries its INACTIVE banner and lags at `board-v98` overall. Only the
  section this turn touched is current. That is #95, not this ticket.
- `#47`, the PAT in `localStorage`, is unchanged. One more read, against a private repo.
