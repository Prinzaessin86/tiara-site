# AD-0002. The finish gate runs here, and device proof is not one of the things it can prove

**Status:** Accepted
**Date:** 2026-08-15
**Ticket:** [tiara-site#100](https://github.com/Prinzaessin86/tiara-site/issues/100)
**Enforced by:** `.claude/settings.json` and the six hooks installed by
`_bootstrap/scripts/install-enforcement.sh`, plus this document for the one guarantee that is
deliberately absent.

## The problem

This repo has carried no enforcement layer at all: no `settings.json`, no hooks, no manifest. The
root `CLAUDE.md` states the deny rules, the bash guard, the `CHANGED` reconciliation and the finish
gate as unconditional, and none of them applied to work done here. It is the least guarded repo in
the estate and it writes to every board in it.

Installing the layer fixes most of that. It does not fix all of it, and the part it cannot fix is
the part most likely to be assumed working.

`verify-on-stop.sh:278` demands a device artefact when a turn touches a UI file:

```sh
UI_PATTERN='(View\.swift$|/Views/.*\.(swift|xib|storyboard)$|\.xib$|\.storyboard$)'
```

`index.html` matches none of it, so the check never fires here. The obvious repair is to retune the
pattern to `index.html`, and that repair is wrong.

## The decision

**Install the layer with `UI_PATTERN` left exactly as it is, and record here that device proof does
not apply to this repo.**

Three things follow, and they should be read as the whole decision rather than as a preamble to it:

1. **Device proof is not automatable here, and a gate that cannot be satisfied honestly should not
   be armed.** Tested rather than assumed: the page was rendered headless at 375px, and what a
   machine can capture without a token is the signed-out onboarding panel, "Connect Tiara to your
   GitHub" with a token field and "reading your boards...". The board, every tab, every row action
   and every health check are behind that. So an artefact dropped into `.artifacts/` would satisfy
   the check while showing none of what changed. That is a check reporting something other than
   what it claims, which is the defect this board keeps filing against itself.

2. **The visual check here is a human opening the page**

## What the gate does prove here, after the install

- `guard-bash.sh` and `guard-scope.sh` bind: the deny rules, the decision-log lock, the
  `.claude/` self-protection and the board-door rules all apply to work in this repo for the first
  time. Including the routes closed today under `BOOT-113`, `BOOT-92` and `_bootstrap#118`.
- `verify-on-stop.sh` binds for the finish block, the `CHANGED`-versus-diff reconciliation and the
  build gate. `make verify` runs the token lint, the script syntax check and the `TIARA_VERSION`
  declaration.
- `swift-quality.sh` is installed and inert: `swift-quality.sh:86` exits 0 for anything that is not
  `.swift`. That is correct and needs no special case.
- `conform.sh` reads `kind: infrastructure` from the registry, so app-only checks report `n/a`,
  exactly as they do in `_bootstrap`.

## What it does not prove, stated so nobody assumes otherwise

- **That the page renders correctly.** No screenshot gate fires here and none should. A change to
  `index.html` is proven by a human looking at the live page, not by an artefact.
- **That the board still works.** Nothing in the gate signs in, so no automated check exercises the
  authenticated path at all.

An agent working in this repo must not report "device proof passed" or treat the absence of a
device-proof failure as evidence that the page is correct. The correct sentence in a finish block is
that the visual change was not verified and needs a human at the page.

## What this does not decide

- Whether `UI_PATTERN` should become per-repo configurable rather than a constant in the template.
  That is a factory question and belongs in `_bootstrap`, not here.
- Anything about `tiara-site#95`'s outstanding visual judgement, which stays a human's.
- Anything about the symbol-design work in `tiara-site#85`, which is still owed its own
  proposal. It does not reserve a number: its Deliverable names `docs/decisions/proposed/`
  and nothing more, so the next accepted app decision is `AD-0003`.
