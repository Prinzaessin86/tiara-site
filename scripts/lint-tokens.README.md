# `lint-tokens.py`, and where it runs

The design system's one rule: a size, a colour and a radius are declared once in `:root` and
referenced everywhere else (AD-0001 decision 1a,
[#77](https://github.com/Prinzaessin86/tiara-site/issues/77)). This script refuses the alternative.

## It is wired in, by two routes

**On every commit.** It runs in `scripts/hooks/pre-commit`, which is installed through
`core.hooksPath`. Every commit that touches `index.html` is linted **before** it is created, on the
staged content.

**On every turn.** `Makefile`'s `lint` target is `python3 scripts/lint-tokens.py index.html`, and
`lint` is the first thing `verify` depends on. The finish gate runs `make verify` to end a turn, so
the rule is checked against the **working tree** whether or not you commit. The two routes check
different content on purpose: the hook checks what is about to be committed, `make verify` catches
it before you stage.

So this is a gate twice over, and neither route is optional
([#120](https://github.com/Prinzaessin86/tiara-site/issues/120)).

This file used to say the opposite, "It is not wired in", and carried a patch for a human to
apply. The patch was applied, in `1f518cd`, and the paragraph was never corrected, so the README
told you the gate was off for as long as it has been on
([#99](https://github.com/Prinzaessin86/tiara-site/issues/99)).

**What it checks:** the `<style>` block outside `:root`, every `style="…"` attribute, and
single-quoted colour literals in JavaScript. That is everywhere CSS is written, with one stated
exemption: SVG presentation attributes (`fill="#…"`, `stroke="#…"`), because `var()` is not valid
in one.

**What happens when it fails.** The commit is refused. The hook prints every raw value with its
line number and what to do about each, then exits non-zero:

```
⛔ lint-tokens: 2 raw values in index.html
   index.html:412  raw colour #ff00aa
        → add it to the COLOUR block in :root and use var(--…)
```

**There is no bypass.** `TIARA_SKIP_DOC=1` waives the doc-and-version checkpoint in the same hook;
it does not waive this. The lint runs first and its exit status is checked before that flag is read.

**It lints the STAGED content, not your working tree**, `git show :index.html`, so what is checked
is exactly what is about to be committed. Note `rc` is captured from the command itself and not from
a pipeline: `python3 … | sed` would report sed's status and the gate would pass while printing its
own refusal.

## Running it by hand

```bash
python3 scripts/lint-tokens.py index.html     # 🎀 every size, colour and radius comes from a token
make lint                                     # the same check, the way verify runs it
```

## Proving it is live rather than vacuous

A check nobody has watched fail is not a check. Induce one:

- `color:#ff00aa` in any rule outside `:root`
- `c:'#123456'` in a JavaScript literal
- `style="color:#abcdef"` on any element
- `border-radius:7px` or `font-size:13px` outside `:root`

Each is reported with its line and its fix. Take it out again and the run goes green.

## A known hole

The JavaScript scan matches **single-quoted** hex only, preceded by `:` or `,`. A double-quoted
`ink: "#6d38b0"` is not caught, and neither is a raw `font-size` or `border-radius` inside a
JS-built style string that is not a `style="…"` attribute. Nothing in `index.html` exploits this
today. Tracked as [#102](https://github.com/Prinzaessin86/tiara-site/issues/102).

## If you install the hook fresh

`core.hooksPath` is per-clone. On a new clone, re-enable it once:

```bash
git config core.hooksPath scripts/hooks
```
