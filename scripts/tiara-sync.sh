#!/usr/bin/env bash
# ========================================================================
#  🐙  Tiara sync  —  the one button.
#
#  Keeps your board agreeing with itself everywhere it lives:
#      your Mac  ⇄  GitHub  ⇄  the live page  ⇄  the private how-it-works doc
#
#  Three ways to run it:
#     bash scripts/tiara-sync.sh            → normal: fixes things, asks before anything risky
#     bash scripts/tiara-sync.sh --check    → look only, change nothing
#     bash scripts/tiara-sync.sh --auto     → hands-off: does the SAFE fixes silently
#                                             (used by the background schedule & Claude Code)
#  Safe by default: it never throws away your work without asking.
# ========================================================================
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR/.." || { echo "can't find the tiara-site folder"; exit 1; }

REPO="Prinzaessin86/tiara-site"      # this public repo (board + live page)
DOC_REPO="Prinzaessin86/tiara"       # private repo holding the how-it-works doc
FALLBACK_PAGES="https://prinzaessin86.github.io/tiara-site/"

MODE="fix"
case "${1:-}" in
  --check) MODE="check" ;;
  --auto)  MODE="auto"  ;;
esac

# --- pretty (no colour when writing to a log, i.e. no terminal) ---
if [ -t 1 ]; then C1="\033[1m"; CG="\033[32m"; CY="\033[33m"; C0="\033[0m"; else C1=""; CG=""; CY=""; C0=""; fi
bold(){ printf "%b%s%b\n" "$C1" "$1" "$C0"; }
ok(){   printf "  %b✅ %s%b\n" "$CG" "$1" "$C0"; }
warn(){ printf "  %b⚠️  %s%b\n" "$CY" "$1" "$C0"; }
info(){ printf "  •  %s\n" "$1"; }
step(){ printf "\n%b%s%b\n" "$C1" "$1" "$C0"; }
ISSUES=0
stamp=$(date -u +%FT%TZ)

echo
bold "🐙  Tiara sync — $stamp  [$MODE]"

# --- 0. tidy any leftover git lock ---
[ -f .git/index.lock ] && rm -f .git/index.lock && info "cleared a leftover git lock"
[ -f .git/DELETE-ME-index.lock.bak ] && rm -f .git/DELETE-ME-index.lock.bak

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
UPSTREAM="origin/$BRANCH"

# --- 1. talk to GitHub ---
step "1. Checking GitHub…"
if git fetch --quiet origin 2>/dev/null; then
  ok "reached GitHub"
else
  warn "couldn't reach GitHub — offline? (local info only)"; ISSUES=$((ISSUES+1))
fi
AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
BEHIND=$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)

# --- 2. your uncommitted work (ignore .DS_Store noise) ---
step "2. Your unsaved work…"
DIRTY=$(git status --porcelain 2>/dev/null | grep -v 'DS_Store' || true)
if [ -n "$DIRTY" ]; then
  warn "changes on your Mac that aren't committed:"
  git status --porcelain 2>/dev/null | grep -v 'DS_Store' | sed 's/^/       /'
  if [ "$MODE" = "fix" ]; then
    printf "\n     What now?  [c]ommit & push   [k]eep as-is   [d]iscard (take GitHub's) : "
    read -r ans </dev/tty
    case "$ans" in
      c|C)
        printf "     one-line message: "; read -r msg </dev/tty
        [ -z "$msg" ] && msg="board: update $stamp"
        git add -A; git reset -q -- '*.DS_Store' 2>/dev/null
        if git commit -q -m "$msg"; then ok "committed"
        else warn "commit was stopped (often the index.html version-bump hook) — see message above"; ISSUES=$((ISSUES+1)); fi ;;
      d|D) git checkout -- . 2>/dev/null && ok "discarded local changes — GitHub's copy wins" ;;
      *)   info "left them alone — they're still only on your Mac"; ISSUES=$((ISSUES+1)) ;;
    esac
    AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
  else
    # check + auto: never touch your uncommitted work automatically
    info "leaving these for you (run the button normally to decide what to do)"
    ISSUES=$((ISSUES+1))
  fi
else
  ok "nothing uncommitted — your Mac is clean"
fi

# --- 3. line up with GitHub ---
step "3. Lining up with GitHub…"
CAN_WRITE=0; [ "$MODE" != "check" ] && CAN_WRITE=1
if [ "$BEHIND" -gt 0 ] && [ "$AHEAD" -gt 0 ]; then
  warn "you and GitHub each have commits the other doesn't (yours: $AHEAD, theirs: $BEHIND)"
  if [ "$MODE" = "fix" ]; then
    if git pull --rebase --quiet 2>/dev/null; then ok "replayed your work on top of GitHub's"
    else warn "hit a conflict — backed out so nothing got mangled; run 'git status' or ask Claude Code"; git rebase --abort >/dev/null 2>&1; ISSUES=$((ISSUES+1)); fi
  else
    info "won't auto-merge a two-way split — run the button normally so you can watch it"; ISSUES=$((ISSUES+1))
  fi
elif [ "$BEHIND" -gt 0 ]; then
  info "GitHub has $BEHIND newer commit(s) your Mac is missing"
  if [ "$CAN_WRITE" = "1" ]; then
    if git merge --ff-only --quiet "$UPSTREAM" 2>/dev/null; then ok "pulled them down — your Mac is caught up"
    else warn "couldn't fast-forward (likely your uncommitted edits are in the way); try: git pull --rebase"; ISSUES=$((ISSUES+1)); fi
  else ISSUES=$((ISSUES+1)); fi
else
  ok "your Mac already has everything GitHub has"
fi
AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
if [ "$AHEAD" -gt 0 ]; then
  info "$AHEAD commit(s) on your Mac not on GitHub yet"
  if [ "$CAN_WRITE" = "1" ]; then
    if git push --quiet 2>/dev/null; then ok "pushed to GitHub"; else warn "push failed; try: git push"; ISSUES=$((ISSUES+1)); fi
  else ISSUES=$((ISSUES+1)); fi
fi

# --- 4. board version agrees everywhere ---
step "4. Board version — your page, GitHub & the live site…"
localv=$(grep -E "TIARA_VERSION" index.html 2>/dev/null | grep -oE "board-v[0-9]+" | head -1)
ghv=$(git show "$UPSTREAM:index.html" 2>/dev/null | grep -E "TIARA_VERSION" | grep -oE "board-v[0-9]+" | head -1)
info "your Mac: ${localv:-?}    GitHub: ${ghv:-?}"
PAGES_URL=$(gh api "repos/$REPO/pages" --jq .html_url 2>/dev/null)
[ -z "$PAGES_URL" ] && PAGES_URL="$FALLBACK_PAGES"
livev=$(curl -fsSL "$PAGES_URL" 2>/dev/null | grep -oE "board-v[0-9]+" | head -1)
info "live page: ${livev:-could not read}  ($PAGES_URL)"
if [ -n "$localv" ] && [ "$localv" = "$ghv" ]; then
  if [ -z "$livev" ] || [ "$livev" = "$ghv" ]; then ok "versions agree ($localv)"
  else warn "live page still shows $livev vs $ghv — GitHub Pages rebuilds ~1 min after a push; re-check shortly"; fi
else
  warn "Mac ($localv) and GitHub ($ghv) disagree — run the button normally, or commit+push your index.html"; ISSUES=$((ISSUES+1))
fi

# --- 5. private how-it-works doc in step ---
step "5. The private how-it-works doc…"
docraw=$(gh api "repos/$DOC_REPO/contents/docs/HOW-TIARA-WORKS.md" -H "Accept: application/vnd.github.raw" 2>/dev/null)
if [ -z "$docraw" ]; then
  warn "couldn't read the private doc — check 'gh auth status' and access to $DOC_REPO"; ISSUES=$((ISSUES+1))
else
  docv=$(printf '%s' "$docraw" | grep -oE "board-v[0-9]+" | head -1)
  if [ -z "$docv" ]; then info "doc reachable, but no board-vNN marker to compare (consider stamping the version in it)"
  elif [ "$docv" = "$ghv" ]; then ok "doc matches the live board ($docv)"
  else warn "doc says $docv but the board is $ghv — the doc has fallen behind; update docs/HOW-TIARA-WORKS.md in '$DOC_REPO'"; ISSUES=$((ISSUES+1)); fi
fi

# --- verdict ---
printf "\n%b—————————————————————————————%b\n" "$C1" "$C0"
if [ "$ISSUES" -eq 0 ]; then
  bold "🎀  All aligned. Your board is telling the truth."
else
  bold "⚠️  $ISSUES thing(s) want a look — see the ⚠️ lines above."
  [ "$MODE" = "check" ] && info "look-only run — use the normal button to fix what's fixable"
fi
echo
[ "$ISSUES" -eq 0 ]
