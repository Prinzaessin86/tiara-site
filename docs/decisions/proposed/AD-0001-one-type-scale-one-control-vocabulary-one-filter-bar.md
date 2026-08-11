# AD-0001. One type scale, one control vocabulary, one filter bar

**Status:** Proposed
**Date:** 2026-08-11
**Ticket:** [tiara-site#75](https://github.com/Prinzaessin86/tiara-site/issues/75)
**Mockup:** `tiara/docs/ux-overhaul-mockup-board-v76.html` (private repo, open it in a browser)
**Measured against:** `board-v76`. `board-v77` landed while this was being written and changed only
code comments.
**Would be enforced by:** a `scripts/hooks/pre-commit` rule that fails a raw `font-size`, hex colour
or `border-radius` anywhere in `index.html`, with an allowlist for the `:root` token block.

## Context

The ticket says the page is not well formatted in terms of text sizes, that some controls are off,
that it is hard to tell which things belong together once something is expanded, that it can lead
to endless scrolling, that it is not always clear what a button does or where a piece of text
belongs, and that there is not enough searching and filtering.

Measured against `index.html`, all six are true. Every number below was counted by script or
computed, not estimated.

**There is no scale.** The stylesheet uses **39 distinct `font-size` values** and not one comes from
a token. It carries **123 distinct hex colours** inside `<style>` (128 across the file) next to a
documented six-token ink set, **25 distinct border radii**, and **81 distinct padding values split
37 px to 43 rem**. The two radius tokens the file appears to have, `--r-md` and `--r-lg`, are
**never defined in `:root`**: all eleven uses fall through to their literal fallback. Two controls
that mean the same thing are almost never the same size, and the difference is never deliberate.

**Every chip label on a queue row fails the squint test.** Measured against the row fill `#fdfaff`,
using the colours in `PRIO_META`, `STATUS_META` and `TYPE_META`:

| Label | Contrast | | Label | Contrast |
|---|---|---|---|---|
| priority high | 3.82:1 | | status doing | 2.42:1 |
| priority med | **2.42:1** | | status verify | 2.42:1 |
| priority low | **2.29:1** | | status done | **2.29:1** |
| type chip (`--soft`) | 3.73:1 | | status new | 3.99:1 |

Nothing reaches 4.5:1, and the chip's own 10% tint fill lowers each figure slightly further. The
file's own `:root` comment says these brights "run 2.1:1 to 4.0:1 … fine as shapes and unreadable as
text", and the six `-i` ink twins exist to fix exactly this. They are dead: each is used once, in
its own definition. On the same fill they measure **4.96:1 to 7.14:1**.

**A control's shape does not tell you what it does.** The page states the rule for the toolbar - a
button is solid and does something, a toggle is a hollow pill, a link has no chrome - and a queue
row breaks it. Eight controls, four of them bare glyphs:

| Control | Looks like | Does | How you would know |
|---|---|---|---|
| ⠿ | a glyph | drags to reorder | you would not |
| priority | a filled chip | **cycles** high → med → low on click | a `title` on hover |
| status | a native `<select>` | opens a list, writes the Lane | it looks like a menu ✓ |
| id + title | text | nothing | ✓ |
| type | grey text | **cycles** bug → feature → chore on click | a `title` on hover |
| #N↗ | a small tinted pill | opens GitHub | ✓ |
| ▸ | a glyph | opens the details panel | you would not |
| ✕ | a glyph | **closes the issue on GitHub**, `title="delete"` | you would not, and the word is wrong |

Three interaction models sit side by side, and the two cycling ones are invisible: nothing on screen
says a click changes the value, the cycle cannot go backwards, and every click writes to a real
board. The most destructive control on the row is the smallest, is a bare glyph, and is labelled
with a word for something else.

**Nothing on the page is reachable from a keyboard.** The whole file contains zero `tabindex`, one
`role=` and one `aria-` (both on a decorative SVG), and no `Escape` handling. Priority and type are
`<span onclick>`: unfocusable, unnameable, invisible to a screen reader. So are all five tabs, the
grip, and the tappable title on a Task queue row.

**Depth stops reading as depth.** An expanded item nests three containers with distinct chrome -
app card, `.detail`, `.bsec` - and four inside the Done lane, all of them pale lavender-to-white.
The panel does name its ticket's id in `.dmeta`; what it omits is the **title**, so in a long list
the thing you are reading is identified only by a number.

**Searching and filtering is per-surface and was never finished.** Task queue has query, lane chips,
project chips, sort and view; a project page has query and lane chips; Portfolio, the main tab, has
neither. No surface filters by **type** or **priority**, and only Task queue can sort at all, so
"this app's oldest untriaged first" is unreachable from anywhere.

**"Untriaged" is currently unrepresentable, and the page is the reason.** An item with no Priority on
the GitHub board is turned into `'med'` twice on the way in: `loadBoardItems` does
`priority:((n.priority&&n.priority.name)||'Med').toLowerCase()`, and `migrate()` does
`if(!q.priority) q.priority='med'`. Type's empty state is deliberately preserved a line above, with
the comment "no Type on the board means untriaged". So the row displays a priority nobody set, and
no filter could find those items even if one existed.

**Nothing is capped on the main tab.** A project page pages at 10 and Task queue flat mode at 25,
but a Portfolio card renders its entire open queue inline, and any number of detail panels can be
open at once, each carrying a full issue body and every comment on it.

**One live bug sits under all of this.** `onRowReorder` rebuilds the whole queue from the visible
DOM - `let k=0; a.queue=a.queue.map(q=> q.status==='done' ? q : activeObjs[k++])` - and its only
guard compares two numbers both read from that same DOM. Today every active row is rendered, so it
holds. The moment any Portfolio list is capped or filtered, a single drag writes `undefined` into
every queue slot past the visible ones, `migrate()` reads `q.id` off `undefined`, `render()` throws
before it assigns `innerHTML`, and the board blanks. This is why decision 6 cannot ship first.

## Decision

Eight changes. They are ordered, and the order is not cosmetic: 0 is a prerequisite for 6, and 1a is
a prerequisite for everything.

### 0. Fix `onRowReorder` before anything is capped or filtered

It splices the moved item using its `data-qi` and leaves every other index alone, instead of
rebuilding the array from what happens to be on screen. It is a bug fix on its own ticket, it is
worth doing whether or not the rest of this is approved, and nothing here that hides a row may land
before it.

### 1a. Introduce the tokens at today's exact values, and the lint rule

Six type steps, six spacing steps, four radii, declared in `:root`, each one set to a value the file
already uses. Every rule is rewritten to reference a token. **Pixel-identical by construction**, so
it is reviewable as a diff, and a visual difference is evidence of a mistake.

The lint rule lands with it and covers the **whole file**, not just `<style>`: the twelve chip
colours live in `STATUS_META`, `TYPE_META` and `PRIO_META` as JS literals and reach the DOM through
`style="background:${m.c}1a;color:${m.c}"`, which is exactly where the contrast failures are. Those
tables move to token names in the same change.

### 1b. Collapse the scale

| Token | Size | Used for |
|---|---|---|
| `--t-xs` | `.72rem` | chips, ids, meta, counts |
| `--t-sm` | `.82rem` | controls, secondary text, table cells |
| `--t-md` | `.92rem` | body text, a row title, a note |
| `--t-lg` | `1.05rem` | a card title, a section heading |
| `--t-xl` | `1.3rem` | a page title |
| `--t-2xl` | `1.85rem` | the Tiara wordmark, once |

This is where 39 sizes become 6, so about 33 declarations move: `.62rem` grows, `1.25rem` and
`1.2rem` land on `--t-lg` or `--t-xl`, `1.45rem` on `--t-xl`. Radii collapse to `.4/.6/.9/999px`,
which moves every card corner, since `.85rem` and `1.15rem` are not steps. `50%` on a dot and the
two multi-corner shorthands are not radius steps and stay as they are.

**This is a deliberate visual change and it cannot be verified by reading the diff.** It ships alone
and is checked with before-and-after screenshots of every surface.

### 1c. A label is the ink twin. A bright is a fill, a dot or a bar

Every chip label uses the `-i` twin of its colour; the bright survives only as the tint, the dot and
the gradient. The three priority twins that do not exist yet are added. This is the rule the file
already wrote down and then did not follow, and it is what makes a row readable at a glance.

### 2. A value you can change is a menu. Click-to-cycle is deleted

Priority and type become the same control status already is. `chipSel(id,i,kind)` **already handles
`'prio'` and `'type'`** and already emits a labelled menu with every value in it; it is only ever
called with `'status'`. So this is three call sites, not a new component.

It carries one trap that must be fixed in the same change: `chipSel`'s prio and type branches point
at `setPrio` and `setType`, which are `q.priority=v; touch()` - **no `bSetField`, no optimistic
update, no rollback**. Swapping the chips in as they stand would silently stop writing priority and
type to GitHub. Both get the body `cyclePriority` and `cycleType` already have, with an explicit
target value.

It stays a native `<select>`. That is free keyboard support, free Escape, free outside-click, and on
a phone a native sheet that cannot open off-screen - none of which exists in this file today, and
all of which a custom popover would have to invent.

### 3. A destructive action is never a bare glyph beside a benign one, and a row fits a phone

The row keeps status, priority, id, title, type, `#N↗` and the caret, and the caret carries the word
**details** (**close** when open). `✕` moves into a `⋯` overflow menu as **Close issue on GitHub**,
which is what it does. The confirmation stays.

The Portfolio **card header** gets the same treatment, because it is at least as confusing as the
row: `⠿`, `▲▼` at `.62rem`, a `✈` toggle, a pencil, an editable `repo:` line and Remove project.
Rename, TestFlight, ▲▼ and Remove move into a `⋯` menu with words on them. The header keeps the
name, the state and the counts.

The phone rules land here too: `.row` gains `flex-wrap:wrap` under 640px (only `.prow` has it
today), and every row control gets `min-height:2.75rem` on a coarse pointer. Today's
`@media(pointer:coarse)` block reaches five controls, all of them still under 44px, and skips the
type chip, the grip and the `#N↗` link entirely.

### 4. An expanded panel belongs to its row, says which row, and is bounded

The row and its panel become one outlined block with a tinted rail down the left edge. Inside it,
sections are divided by a rule and a label, not by a card inside a card. The existing `.dmeta`
header gains the **title** next to the id it already prints.

The panel shows Acceptance and the newest note, with a `max-height` and its own scroll. Everything
else is what **open full page ⤢** is for, and that button already exists in the panel header. This,
not a limit on how many panels are open, is what stops a list scrolling forever: the height of one
panel is the problem, and comparing two tickets side by side is the reason this page exists.

### 5. One filter bar, on all three surfaces

One component, used by Portfolio, Task queue and a project page: **query**, **lane**, **type**,
**priority**, **project** (Task queue only), **sort**, and two quick chips - **untriaged** and
**needs verify**. Every chip states the count it would give you. Active filters appear as removable
chips that say what they are doing, above the results, with a Clear all.

It has a data-model prerequisite, from the Context: an absent Priority must survive as `''` instead
of becoming `'med'`, the `migrate()` default goes, and `PRIO_META` gains a `none` entry that renders
**not set**. That changes what those rows display today, which is the point, and it is a visible
change this decision owns.

Filters serialise into the URL so a filtered view can be linked and reloaded, and a plain load still
starts empty. Four things in the current router have to change with it, or a linked view opens the
wrong tab: `applyHash` splits on `?` before the `TAB_FOR` lookup; `routeOf` decodes per parameter
rather than the whole hash at once; a filter change uses `history.replaceState`, because `setHash`
pushes a history entry and a serialised query box would otherwise cost one Back press per keystroke;
and `showTab` preserves the current surface's parameters instead of dropping them.

Under 640px the bar collapses to a single **Filters (2)** button that opens it, because five menus, a
query box, two quick chips, thirteen project chips and the active-filter row would otherwise stack
six deep above the first result on a phone.

### 6. Nothing on a surface is unbounded

A Portfolio card renders the first **10** of its open queue and then a line reading *showing 10 of
34 · open the project page for the rest*. The review counted three boards over 30 open items today,
so this is not hypothetical; that count is the review's, read live from the API, and was not
re-checked here. It ships **after decision 0**, and not before.

## Consequences

The page gets smaller and duller in the good sense: fewer sizes, fewer greys, fewer shapes, and one
answer to "what does this control do". A row becomes scannable because every row is the same row.

Four costs, stated plainly.

**Muscle memory breaks once.** Click-to-cycle on priority and type is gone, and `✕` is one click
further away. That is the point of both changes and it is still a loss on the day it ships.

**1b and 1c are visible, and 1c changes colours you know.** A label that has been a pale pink
becomes a dark one. It will look heavier. It will also be readable.

**Rows will display a priority they do not have.** After decision 5's data change, every item filed
before TIA-65 stops claiming `med` and starts saying **not set**. That is a truthful screen and an
uglier one.

**Decision 6 makes the Portfolio card a summary rather than the whole truth.** An app with 34 open
items can no longer be worked entirely from its card. The project page exists for that and pages at
10 already.

Deliberately not decided here: the Compliance grid's density, the Runbook and Knowledge tabs (prose,
already at a comfortable measure), keyboard access for the tabs and the grip (real, and its own
ticket), and any move off GitHub Pages.

## How this would ship

Eight tickets, in this order. Each is shippable alone.

| Order | Change | Size | Verified by |
|---|---|---|---|
| 0 | `onRowReorder` splices instead of rebuilding | small | a drag on a filtered list, before and after |
| 1a | Tokens at today's values, plus the lint rule | large, mechanical | the diff, and pixel-identical screenshots |
| 1b | Collapse the scale and the radii | large | before-and-after screenshots of every surface |
| 1c | Labels move to the ink twins | medium | measured contrast, every chip ≥ 4.5:1 |
| 2 | `chipSel` for prio and type, and the write path they are missing | small | a chip change reaching GitHub, and reverting on failure |
| 3 | `⋯` on the row and the card header, phone rules | medium | a 375px screenshot, and a tap target audit |
| 4 | The panel | medium | a long list, one panel open |
| 5 | The filter bar, the priority data change, the router | large | a linked filtered URL that opens the right tab |
| 6 | The card cap | small | a 34-item card, and a drag on it |

## The subagent review this ticket asked for

A subagent read this design and `index.html` and returned twelve findings. Every claim of fact in it
was re-checked against the code here before being accepted; the four that changed the code's meaning
were verified line by line. The design above **is** the design after the review. What it changed:

| # | Finding | Verdict |
|---|---|---|
| 1 | The cap in decision 6 makes `onRowReorder` write `undefined` into the queue and `render()` throw | **Taken.** Verified at `index.html:1601`. It became decision 0, and decision 6 now depends on it |
| 2 | "Untriaged" cannot be built: an absent Priority is turned into `'med'` at load and again in `migrate()` | **Taken.** Verified at `:903` and `:1632`. Decision 5 now carries the data-model change and owns its visible effect |
| 3 | "1 lands with no intended visual change" is false, and `--r-md`/`--r-lg` are never defined in `:root` | **Taken.** Verified. Split into 1a (identical) and 1b (deliberate), which also resolves the contradiction of claiming no visual change and demanding screenshots |
| 4 | `chipSel` already does prio and type; its `setPrio`/`setType` do not write to GitHub, so decision 2 as written would silently stop saving | **Taken.** Verified at `:1779-1791`. Decision 2 is now three call sites plus the missing write path |
| 5 | Every chip label already fails the squint test and the design did not say so | **Taken.** Re-measured here rather than taking the numbers on trust: 2.29:1 to 3.99:1, twins 4.96:1 to 7.14:1. It became decision 1c |
| 6 | Zero keyboard reachability; keep the native `<select>` rather than build a popover | **Taken.** Decision 2 keeps `<select>` and says why. Tabs and grip are named as out of scope, not silently dropped |
| 7 | `.row` never wraps and four of eight controls are under 20px on a phone | **Taken.** Verified. Folded into decision 3, and decision 5 gained the collapsed **Filters (2)** bar |
| 8 | The URL claim does not work against the router that exists: `TAB_FOR` misses, whole-hash decode, `location.hash` pushes history, `showTab` strips the query | **Taken.** Verified. Decision 5 now names all four changes |
| 9 | Four facts wrong: 123 hex not 127, the panel does print its id, the nesting is three deep not five, and the untriaged count needs its scope | **Taken.** Recounted: 123 in `<style>`, 128 in the file. The nesting and panel claims were wrong because `.lane.q` is transparent and `.detail` is a sibling of the row, not a child. All rewritten, and the count now describes the data-model bug rather than quoting a stale number |
| 10 | The lint rule would miss the JS colour tables, and the mockup itself breaks decision 1 | **Taken.** The rule now covers the whole file. The mockup's proposed panels were moved onto tokens; its "today" panels keep raw values on purpose, and say so |
| 11 | Drop "one open panel per list": `openState` is one global set, and the height of a panel is the real problem | **Taken.** Decision 4 bounds the panel instead. The card cap stays |
| 12 | The card header, and no sort anywhere but Task queue | **Taken** for both: the header is in decision 3, sort is in decision 5. Preset filter chips were left out; the quick chips already cover the two that matter |

**What the review could not check, in its own words:** it did not run the page in a browser, so its
layout and contrast figures were computed from the CSS rather than measured on a rendered surface;
it did not read the minified SortableJS body, so its reorder analysis assumes standard `onEnd`
semantics; and it could not tie the untriaged count to a stated scope. The contrast figures in this
document are the ones re-computed here.
