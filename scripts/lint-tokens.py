#!/usr/bin/env python3
"""The design system's lint rule (AD-0001 decision 1a, tiara-site#77).

A size, a colour or a radius is declared once, in `:root`, and referenced everywhere else. This
refuses the alternative. Without it the scale decays: the file reached 39 distinct font sizes, 123
hex colours and 25 radii precisely because nothing said no.

Run:  python3 scripts/lint-tokens.py [index.html]
Exit: 0 clean, 1 with a list of file:line and what to do about each.

Where it looks: the `<style>` block outside `:root`, every `style="…"` attribute, and every style
string the JavaScript builds. That is everywhere CSS is written.

The one exemption, stated rather than silent: SVG **presentation attributes** (`fill="#…"`,
`stroke="#…"`). `var()` is not valid in a presentation attribute, so the Knowledge tab's diagram
cannot use a token there. Give the element a class and colour it from CSS if you want it linted.
"""
import re, sys

PATH = sys.argv[1] if len(sys.argv) > 1 else 'index.html'
src = open(PATH, encoding='utf-8').read()
lines = src.split('\n')
def lineno(i): return src.count('\n', 0, i) + 1

fails = []
def fail(pos, what, fix):
    fails.append((lineno(pos), what, fix))

# ---------------------------------------------------------------- the stylesheet
m = re.search(r'<style>(.*?)</style>', src, re.S)
if not m: sys.exit('lint-tokens: no <style> block in ' + PATH)
style_at = m.start(1)
style = m.group(1)

rm = re.search(r':root\{.*?\n  \}', style, re.S)
if not rm: sys.exit('lint-tokens: no :root block, so there is nowhere for a token to live')
root_span = (rm.start(), rm.end())
def in_root(i): return root_span[0] <= i < root_span[1]

LEN = r'(?:\d*\.?\d+)(?:rem|em|px|ch|vw|vh)'

for mo in re.finditer(r'font-size:\s*([^;}\n]+)', style):
    if in_root(mo.start()): continue
    v = mo.group(1).strip()
    if v.startswith('var(') or v.startswith('clamp(') or v == 'inherit': continue
    fail(style_at + mo.start(), 'raw font-size: ' + v,
         'add it to the TYPE block in :root and use var(--t-…)')

for mo in re.finditer(r'border-radius:\s*([^;}\n]+)', style):
    if in_root(mo.start()): continue
    for part in mo.group(1).split():
        if part in ('0',) or part.startswith('var(') or part.endswith('%'): continue
        fail(style_at + mo.start(), 'raw border-radius: ' + mo.group(1).strip(),
             'add it to the RADIUS block in :root and use var(--r-…)')
        break

for mo in re.finditer(r'#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b', style):
    if in_root(mo.start()): continue
    fail(style_at + mo.start(), 'raw colour ' + mo.group(0),
         'add it to the COLOUR block in :root and use var(--…)')

# ---------------------------------------------------------------- inline CSS, markup and JS
# A style attribute, and the style strings the row builders write. Both are CSS.
rest = src[:style_at] + ' ' * len(style) + src[m.end(1):]
for mo in re.finditer(r'style\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|`([^`]*)`)', rest):
    val = mo.group(1) or mo.group(2) or mo.group(3) or ''
    for hit in re.finditer(r'#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b', val):
        fail(mo.start(), 'raw colour ' + hit.group(0) + ' in a style attribute',
             'use var(--…); the token is in :root')
    for hit in re.finditer(r'font-size:\s*(' + LEN + ')', val):
        fail(mo.start(), 'raw font-size ' + hit.group(1) + ' in a style attribute', 'use var(--t-…)')
    for hit in re.finditer(r'border-radius:\s*(' + LEN + ')', val):
        fail(mo.start(), 'raw border-radius ' + hit.group(1) + ' in a style attribute', 'use var(--r-…)')

# A colour sitting in a JS string is still a colour: this is where the chip palette used to live.
for mo in re.finditer(r"[:,]\s*'(#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3}))'", rest):
    fail(mo.start(), 'raw colour ' + mo.group(1) + ' in a JavaScript literal',
         "declare it in :root and put 'var(--…)' here instead")

if fails:
    print('⛔ lint-tokens: %d raw value%s in %s' % (len(fails), '' if len(fails) == 1 else 's', PATH))
    for ln, what, fix in sorted(fails):
        print('   %s:%d  %s' % (PATH, ln, what))
        print('        → %s' % fix)
    print('   Every size, colour and radius is declared once in :root. AD-0001, decision 1a.')
    sys.exit(1)
print('🎀 lint-tokens: every size, colour and radius comes from a token ✓')
