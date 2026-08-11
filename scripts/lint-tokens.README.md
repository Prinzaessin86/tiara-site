# Wiring `lint-tokens.py` into the gate

The linter is written and passes. **It is not wired in**, because `scripts/hooks/pre-commit` is a
gate script and an agent may not edit one, even to make it stricter. This is the patch, for a human
to apply. [#77](https://github.com/Prinzaessin86/tiara-site/issues/77).

In `scripts/hooks/pre-commit`, immediately after the line

```bash
if git diff --cached --name-only | grep -qx 'index.html'; then
```

insert:

```bash
  # The design system's one rule: a size, a colour and a radius are declared in :root and
  # referenced everywhere else (AD-0001 decision 1a, #77). Linted on the STAGED content, not the
  # working tree, so what is checked is what is committed. No bypass: TIARA_SKIP_DOC waives the
  # doc reminder, never the tokens.
  staged=$(mktemp -t tiara-index) || exit 1
  git show :index.html > "$staged" || exit 1
  out=$(python3 scripts/lint-tokens.py "$staged" 2>&1); rc=$?
  rm -f "$staged"
  printf '%s\n' "${out//$staged/index.html}"
  [ "$rc" = 0 ] || exit 1
```

Note `rc` is captured from the command itself, not from a pipeline: `python3 … | sed` would report
sed's exit status and the gate would pass while printing its own refusal.

## Checking it works

```bash
python3 scripts/lint-tokens.py index.html     # 🎀 every size, colour and radius comes from a token
```

Induce a failure to prove the rule is live rather than vacuous: put `color:#ff00aa` in any rule
outside `:root`, or `c:'#123456'` in a JavaScript literal, or `style="color:#abcdef"` on any
element, and re-run. Each is reported with its line and what to do about it.
