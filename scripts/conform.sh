#!/usr/bin/env bash
# BOOT-71: bash, not sh. This declared #!/bin/sh and the Makefile ran it as `sh`, while using <<<
# herestrings in five places. That works only because macOS /bin/sh IS bash 3.2. On any machine
# where sh is dash it dies at the first one, and make reads the status as a gate failure, so the
# gate would call the repo non-conforming for a reason that has nothing to do with the repo.
# make conform, assert this app still matches the factory's architecture decisions.
# Fails loud on drift. This exists because FD-0001 silently said "no XcodeGen" for weeks
# while the Makefile ran xcodegen, and a whole parallel release mechanism got built without
# anything noticing: nothing checked the code against the decisions. Now something does.
#
# Only machine-checkable, universal ADR claims are asserted here:
#   0001  project.yml is the source of truth; the .xcodeproj is generated + gitignored.
#   0006  exactly one release mechanism (Xcode Cloud); no local archive/upload.
#   secrets never live in the repo.
set -u
fail=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=1; }
# Not applicable is its OWN state. Not green, not red, and visibly neither. A check that is skipped
# and rendered as a pass is how a gate stops meaning anything, which is the whole reason BOOT-44
# refused a `--tooling` flag. (BOOT-44)
na()  { printf '  \033[33m-\033[0m %s \033[2m(n/a: not an app)\033[0m\n' "$1"; }

# --- What kind of repo is this? ------------------------------------------------------
# READ FROM THE REGISTRY, never from the repo. tiara-data.json already carries apps[].kind, it is
# the same source vendor-factory.sh and make-board-ticket.sh derive the fleet from, and it is not a
# file the repo under test can edit to excuse itself.
#
# Deliberately NOT a flag, a marker file or a --tooling argument: any of those is an off switch an
# agent can reach, and checks that can be switched off quietly are not checks.
#
# Deliberately NOT content detection: "does it contain Swift" classifies _bootstrap as an app,
# because its nine Swift files are the scaffold in template/Sources/. Content heuristics fail on
# exactly the repo that matters most.
#
# DEFAULTS TO app, which is the strict answer. An unreadable registry, a missing python3 or a repo
# nobody registered all get the full check set. Leniency is never the fallback.
REPO_KIND=app
_TIARA="${TIARA_DATA:-$HOME/Developer/tiara/tiara-data.json}"
if [ -f "$_TIARA" ] && command -v python3 >/dev/null 2>&1; then
  _k=$(python3 -c '
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
want=sys.argv[2].lower()
for a in d.get("apps",[]):
    if (a.get("repo","").split("/")[-1] or "").lower()==want or (a.get("name","") or "").lower()==want:
        print((a.get("kind") or "").lower()); break
' "$_TIARA" "$(basename "$PWD")" 2>/dev/null)
  [ "$_k" = infrastructure ] && REPO_KIND=tooling
fi
# Content used ONLY to REFUSE a downgrade, never to grant one. A repo that genuinely builds an app
# cannot be excused from the app checks by a registry edit, so the one hole the proposal admitted
# (an agent editing tiara-data.json) buys nothing where it would matter most.
if [ "$REPO_KIND" = tooling ]; then
  _hasproj=""
  [ -f project.yml ] && _hasproj=project.yml
  for _p in *.xcodeproj; do [ -e "$_p" ] && _hasproj="$_p" && break; done
  if [ -n "$_hasproj" ]; then
    bad "the registry calls this infrastructure, but $_hasproj is here, so it builds an app. Checking it as an app. Fix the kind in tiara-data.json, or explain why an app is registered as infrastructure."
    REPO_KIND=app
  fi
fi

echo "==> conform (ADR check)"
[ "$REPO_KIND" = app ] || echo "  kind: tooling (from tiara-data.json). App-only checks report n/a."

# --- CLAUDE.md hygiene (Anthropic: under 200 lines; no history; no root duplication) ------
# Longer files do not just cost context, they reduce adherence, which is why this blocks rather
# than warns. History belongs in git. A root rule restated here is a contradiction in one context
# window, because memory files concatenate rather than override.
claude_md_size() {
  [ -f CLAUDE.md ] || return 0
  local n; n=$(wc -l < CLAUDE.md | tr -d ' ')
  if [ "$n" -gt 200 ]; then
    bad "CLAUDE.md is $n lines, over the 200-line limit by $((n-200)). Longer files reduce adherence. Move knowledge to .claude/rules/ with a paths: glob, procedures to .claude/skills/, history to git."
  fi
}

claude_md_no_history() {
  [ -f CLAUDE.md ] || return 0
  local hits
  hits=$(grep -nEi '^#{1,3} .*(build log|lessons learned|overnight audit|sign-off|open work|sprint|[0-9]{4}-[0-9]{2}-[0-9]{2})' CLAUDE.md 2>/dev/null || true)
  if [ -n "$hits" ]; then
    while IFS= read -r h; do
      bad "CLAUDE.md line ${h%%:*} is history, not a rule: $(printf '%s' "$h" | cut -d: -f2- | cut -c1-70). Git already has it."
    done <<< "$hits"
  fi
}

claude_md_no_todos() {
  [ -f CLAUDE.md ] || return 0
  local hits
  # Case-SENSITIVE for the markers: "TODO:" is a marker, "a todo app" is prose. The heading
  # patterns stay case-insensitive, since a heading's capitalisation varies.
  hits=$( { grep -nE '(^|[^A-Za-z])(TODO|FIXME|TBD|XXX)([^A-Za-z]|$)' CLAUDE.md 2>/dev/null;
            grep -nEi '^#{1,3} .*(finding|open question|to be decided|outstanding|next steps?)' CLAUDE.md 2>/dev/null; } | sort -n -u || true)
  if [ -n "$hits" ]; then
    while IFS= read -r h; do
      bad "CLAUDE.md line ${h%%:*} records work rather than a rule: $(printf '%s' "$h" | cut -d: -f2- | cut -c1-64). A to-do is a ticket. A finding is a ticket or an ADR. Neither belongs in a file loaded every turn."
    done <<< "$hits"
  fi
}

claude_md_no_root_rules() {
  [ -f CLAUDE.md ] || return 0
  local h hits=""
  while IFS= read -r h; do
    grep -qiE "^#{1,3} +${h}\b" CLAUDE.md 2>/dev/null && hits="$hits$h; "
  done <<'ROOTRULES'
The two rules
Hard rules
Verification is not reading
Before you finish any session
Work tracking
How to Update This File
Git Workflow
ROOTRULES
  [ -n "$hits" ] && bad "CLAUDE.md restates root rules: ${hits}Memory files concatenate rather than override, so this contradicts ~/.claude/CLAUDE.md in the same context window. Delete it here."
}

# --- The gate is not relaxed to make something pass ----------------------------------
# A disable comment or a lowered threshold turns a red gate green without changing the code. It is
# the one form of "passing" that leaves no trace in the diff of what it hid.
no_gate_relaxation() {
  local hits
  hits=$(grep -rn --include='*.swift' -E 'swiftlint:disable([^:]|$)' . 2>/dev/null \
         | grep -v '/build/' | grep -v '/DerivedData/' | head -8 || true)
  if [ -n "$hits" ]; then
    while IFS= read -r h; do
      bad "swiftlint:disable at ${h%%:*}:$(printf '%s' "$h" | cut -d: -f2). Fix the code or narrow it to one line with swiftlint:disable:next."
    done <<< "$hits"
  fi
}
no_gate_relaxation

# --- App icons are opaque -------------------------------------------------------------
# A 1024 with an alpha channel renders as a dark icon on the home screen, on device only, with
# nothing in the build to say why. iOS 18 dark and tinted variants are the exception: those are
# composited over a system background and are SUPPOSED to carry alpha, so only an icon that is
# not declared as an appearance variant in Contents.json is checked.
opaque_app_icon() {
  command -v python3 >/dev/null 2>&1 || return 0
  local out
  out=$(python3 - <<'PYEOF'
import os, json, sys
bad = []
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in ('.git','build','DerivedData','.build','Pods')]
    if not root.endswith('.appiconset'): continue
    cj = os.path.join(root, 'Contents.json')
    if not os.path.isfile(cj): continue
    try: images = json.load(open(cj)).get('images', [])
    except Exception: continue
    for im in images:
        fn = im.get('filename')
        if not fn or im.get('appearances'): continue      # a variant may be transparent
        p = os.path.join(root, fn)
        try:
            with open(p, 'rb') as fh: head = fh.read(26)
        except Exception: continue
        if head[:8] != b'\x89PNG\r\n\x1a\n': continue
        if head[25] in (4, 6):                            # IHDR colour type: 4 grey+alpha, 6 RGBA
            bad.append(p)
# BOOT-78: report the count and say it was cut. Truncating at eight silently meant a repo with
# sixteen offending icons was told about eight, and the eight named were whichever sorted first:
# in PodaKnows every one came from AppIcon-Dev (hyphen 0x2D sorts before dot 0x2E) and the PROD
# icons, equally affected, never appeared. Half a problem read as all of it.
_bad = sorted(set(bad))
for b in _bad[:8]:
    print(b)
if len(_bad) > 8:
    print("... and %d more, %d offending icons in total" % (len(_bad) - 8, len(_bad)))
sys.exit(1 if bad else 0)
PYEOF
)
  if [ -n "$out" ]; then
    while IFS= read -r f; do
      bad "$f has an alpha channel. An app icon that is not a dark or tinted variant must be opaque, or it renders dark on the home screen. Flatten it onto an opaque background."
    done <<< "$out"
  fi
}
opaque_app_icon

# --- No dangling references (FD-0000) ------------------------------------------------
# A citation that resolves to nothing is worse than no citation: the next session assumes the
# thing was consulted. Checks markdown link targets and every FD-/AD- id mentioned in prose.
# docs/archive/ is exempt: an archived document keeps the references it had when it was written,
# and rewriting a dated record to satisfy a checker makes it claim knowledge it did not have.
no_dangling_refs() {
  command -v python3 >/dev/null 2>&1 || return 0
  local out
  out=$(python3 - <<'PYEOF'
import os, re, sys
bad = []
ids = set()
for d in ('docs/decisions', 'docs/decisions/factory'):
    if os.path.isdir(d):
        for f in os.listdir(d):
            m = re.match(r'((?:FD|AD)-\d{4})-', f)
            if m: ids.add(m.group(1))
link = re.compile(r'\[[^\]]{0,80}\]\(([^)]+)\)')
ref  = re.compile(r'\b((?:FD|AD)-\d{4})\b')
for root, dirs, files in os.walk('.'):
    dirs[:] = [x for x in dirs if x not in ('.git','build','DerivedData','node_modules','.build','Pods','archive')]
    for fn in files:
        if not fn.endswith('.md'): continue
        p = os.path.join(root, fn)
        try: txt = open(p, encoding='utf-8', errors='replace').read()
        except Exception: continue
        for i, line in enumerate(txt.split('\n'), 1):
            for m in link.finditer(line):
                t = m.group(1).split('#')[0].strip()
                if not t or t.startswith(('http','mailto:','tel:','@')): continue
                if not os.path.exists(os.path.normpath(os.path.join(root, t))):
                    bad.append(f"{p}:{i} link -> {t}")
            # The id check applies where a decision is cited as authority. A decision record may
            # name another repo's decision as an example, which is prose, not a broken reference.
            if root.replace('\\','/').find('docs/decisions') == -1:
                for m in ref.finditer(line):
                    if ids and m.group(1) not in ids:
                        bad.append(f"{p}:{i} cites {m.group(1)}, which does not exist here")
for b in bad[:12]:
    print(b)
sys.exit(1 if bad else 0)
PYEOF
)
  if [ -n "$out" ]; then
    while IFS= read -r l; do bad "dangling reference: $l"; done <<< "$out"
  fi
}
no_dangling_refs

# --- FD-0000: the FD obligation block matches the vendored set ------------------------
# The FD- ADRs are never auto-loaded, so this block is the only thing that puts them in front of an
# agent. Generated, never hand-written, so adding an FD updates every repo through vendor-factory.
#
# The generator is injectable so this check can be tested against a fixture generator (FD-0004).
# Nothing in the fleet sets it; the default is the only path a real repo ever uses.
FD_BLOCK="${FD_BLOCK_BIN:-$HOME/Developer/_bootstrap/scripts/fd-block.sh}"

# THE FIX INSTRUCTION IS A HUMAN'S, AND SAYS SO (BOOT-70).
#
# This used to read "Regenerate it: bash ~/Developer/_bootstrap/scripts/fd-block.sh ." and that
# command fixes nothing for anybody. It only ever printed the block to stdout; it never opened
# CLAUDE.md. The mode that writes is --write, and an agent cannot reach it from here either way:
# the path is outside this project so guard-bash refuses it, and CLAUDE.md is denied to Edit and
# Write unconditionally.
#
# PodaProject sat in that on 2026-08-11: fourteen consecutive Stop blocks, twelve of them
# `BLOCK make verify RED`, and the session ended by overriding the hook rather than by the gate
# passing. A gate that cannot be satisfied by doing the right thing teaches people to route around
# it. BOOT-70 closed the source of it, so this state is now rare rather than routine, and the
# honest answer to a rare state is to name the human who can clear it (FD-0013).
#
# Deliberately NOT solved by allowing fd-block.sh through guard-bash. BOOT-60 closed the
# ~/Developer/_bootstrap/scripts grace period on 2026-08-11 after eight copies had drifted, one of
# them a move-to-verify.sh skipping the criterion check for every ticket. A second allowed path is
# a second answer.
FD_BLOCK_FIX='An agent cannot fix this from here: CLAUDE.md is denied to Edit and Write, and the generator lives outside this project.
    A human, from ~/Developer/_bootstrap:  bash scripts/fd-block.sh --write <this repo>
    or, for the whole fleet:               bash scripts/vendor-factory.sh'

fd_block_current() {
  [ -f CLAUDE.md ] || return 0
  # BOOT-76: KEYED ON THE VENDORED SET, NOT ON THE BLOCK.
  #
  # This used to `grep -q '^## Factory decisions that bind here' CLAUDE.md || return 0`, so a repo
  # carrying the FD- set with no block at all was the one state that passed. Ten repos held the set
  # on 2026-08-11 and five of them had no block: the generated block and the repo's differed by all
  # fifteen lines, and the check never ran to say so. A red gate is noticed within one turn; that
  # was worse, because nothing anywhere reported it.
  #
  # The early return was written for a repo that has not been vendored yet. That condition is
  # "no factory set on disk", which is what it now asks. A repo with nothing vendored still passes.
  [ -d docs/decisions/factory ] || return 0

  if [ ! -f "$FD_BLOCK" ]; then
    bad "the FD block generator is not at $FD_BLOCK, so whether CLAUDE.md matches the vendored factory set is unknown. Clone _bootstrap beside this repo, or set FD_BLOCK_BIN. This check does not pass on a missing generator: it would pass in exactly the case it cannot see."
    return
  fi

  # BOOT-95's REFUSAL HAS TO ARRIVE, NOT BE SWALLOWED.
  #
  # This used to be `gen=$(bash ... 2>/dev/null | grep ...)`, which discarded stderr and the exit
  # status together. fd-block.sh now REFUSES an ADR whose first line is not `# FD-NNNN. Title`,
  # because such a heading drops that decision from the generated block and from this comparison at
  # the same time. Under 2>/dev/null that refusal reached the reader as an empty $gen and a generic
  # mismatch: a repo told its block was wrong, with no way to learn that the real fault was one
  # malformed heading in a file the message never named. The generator is the one place that knows
  # the required shape, so its words are the ones worth printing.
  local gen have rc err
  err=$(mktemp "${TMPDIR:-/tmp}/fdblock.XXXXXX")
  gen=$(bash "$FD_BLOCK" . 2>"$err"); rc=$?
  if [ "$rc" != 0 ]; then
    bad "the FD block could not be generated, so CLAUDE.md cannot be checked against the vendored factory set. $FD_BLOCK said:
$(sed 's/^/    /' "$err")"
    rm -f "$err"
    return
  fi
  rm -f "$err"

  gen=$(printf '%s\n' "$gen" | grep -E '^FD-[0-9]{4}' | sort)
  have=$(sed -n '/^## Factory decisions that bind here/,/^## /p' CLAUDE.md | grep -E '^FD-[0-9]{4}' | sort)

  if ! grep -q '^## Factory decisions that bind here' CLAUDE.md; then
    # The lines themselves, not a count and not the name of a script. A reader in this state has no
    # block at all, and the generator has just produced the exact text that belongs in the file, so
    # withholding it and naming a command instead is the same shape of instruction BOOT-70 removed
    # one message up.
    bad "CLAUDE.md has no FD obligation block, but docs/decisions/factory/ is vendored here. The factory decisions reach nobody: the FD- ADRs are never auto-loaded, so this block is the only thing that puts them in front of an agent. Add the section '## Factory decisions that bind here', carrying these lines:
$(printf '%s\n' "$gen" | sed 's/^/      /')
    $FD_BLOCK_FIX"
    return
  fi

  if [ "$gen" != "$have" ]; then
    bad "the FD obligation block in CLAUDE.md does not match the vendored factory set.
    $FD_BLOCK_FIX"
  fi
}

claude_md_size
claude_md_no_history
claude_md_no_todos
claude_md_no_root_rules
fd_block_current

# --- FD-0010: no GitHub Actions workflow builds or tests -----------------------------
# CI runs on Xcode Cloud and nowhere else, triggered by a version bump. A macOS runner in
# .github/workflows is a second CI on a runner that bills at 10x. Non-macOS workflows (a
# status poller, a docs job) are fine and are not what this forbids.
no_actions_build() {
  local hits
  hits=$(grep -rl 'runs-on:[[:space:]]*macos' .github/workflows 2>/dev/null || true)
  if [ -n "$hits" ]; then
    for f in $hits; do
      bad "$f runs on a macOS GitHub Actions runner. CI is Xcode Cloud, triggered by a version bump (FD-0010). Delete it: git rm $f"
    done
  fi
}
no_actions_build

# --- FD-0011: docs/archive/ is denied on the tool route ------------------------------
# This used to require the block in BOTH layers, settings.json AND guard-bash.sh, on the reasoning
# that a document blocked in one and not the other reads as protected and is not.
#
# BOOT-31 then deliberately removed the guard-bash arm, because `*"docs/archive/"*` matched the path
# anywhere in a command and so refused an agent MOVING a finished document into the archive, which is
# exactly what the rules tell it to do with one. That was the right call for that problem.
#
# Nothing reconciled the two, and nothing noticed, because this check had been dead since before
# BOOT-31 landed: BOOT-63's `grep -c ... || echo 0` made the comparison error out and evaluate false.
# Reviving it in BOOT-63 turned every repo red at once. (BOOT-82)
#
# DECIDED, 2026-08-11, rather than arrived at by a failing check: the tool route is sufficient, and
# the shell route is a KNOWN AND ACCEPTED GAP. `permissions.deny` binds Edit, Write and Read; it does
# not bind Bash. So `cat docs/archive/x.md` is not refused and will not be. FD-0011 exists to stop a
# closed finding being reopened as though it were current, not to stop exfiltration, and an agent
# that wants the contents can read the ticket instead. See
# docs/decisions/proposed/FD-PROPOSED-archive-shell-route.md.
#
# So this now checks the layer that actually binds, and checks it PROPERLY: all three of Edit, Read
# and Write, not merely that the path is mentioned somewhere. A settings.json naming docs/archive
# once, under Read only, used to satisfy the old count.
archive_denied_on_tool_route() {
  local f missing
  f=.claude/settings.json
  if [ ! -f "$f" ]; then
    bad "no .claude/settings.json, so docs/archive/ is denied on no route at all (FD-0011). Run: bash ~/Developer/_bootstrap/scripts/install-enforcement.sh ."
    return
  fi
  missing=""
  for verb in Edit Read Write; do
    grep -q "\"$verb(./docs/archive/\*\*)\"" "$f" || missing="$missing $verb"
  done
  if [ -n "$missing" ]; then
    bad "docs/archive/ is not denied for:$missing on the tool route. All three of Edit, Read and Write must be denied (FD-0011). Run: bash ~/Developer/_bootstrap/scripts/install-enforcement.sh ."
  fi
  # BOTH layers, again, and this time the shell layer exists. BOOT-82 relaxed this to the tool route
  # alone because guard-bash carried no archive block: BOOT-31 had removed it for refusing legitimate
  # archiving, and nothing put a narrower one back. BOOT-83 decided the shell route must be closed
  # too, so the check goes back to requiring both. permissions.deny does not bind Bash, so the tool
  # route on its own leaves `cat docs/archive/x.md` unrefused.
  if ! grep -q 'docs/archive' .claude/hooks/guard-bash.sh 2>/dev/null; then
    bad "docs/archive/ is denied on the tool route but not on the shell route, so it reads as protected and is not: permissions.deny does not bind Bash (FD-0011). Run: bash ~/Developer/_bootstrap/scripts/install-enforcement.sh ."
  fi
}
archive_denied_on_tool_route

# --- FD-0001: project.yml is the source of truth -----------------------------------
if [ "$REPO_KIND" != app ]; then na "project.yml (0001)"
elif [ -f project.yml ]; then ok "project.yml present (0001)"
else bad "project.yml missing, the project must be generated from it (0001)"; fi

proj=""
for p in *.xcodeproj; do [ -e "$p" ] && proj="$p" && break; done
if [ -n "$proj" ]; then
  if git check-ignore -q "$proj" 2>/dev/null; then ok ".xcodeproj is gitignored (0001)"
  else bad "$proj is NOT gitignored, it is generated, never committed (0001)"; fi
  if git ls-files --error-unmatch "$proj" >/dev/null 2>&1; then
    bad "$proj is tracked in git, run: git rm -r --cached '$proj' (0001)"
  else ok ".xcodeproj is not tracked (0001)"; fi
fi

# --- secrets never in the repo ------------------------------------------------------
for pat in release.env 'AuthKey*.p8' Config.xcconfig; do
  hits=$(git ls-files "$pat" 2>/dev/null)
  [ -n "$hits" ] && for f in $hits; do bad "secret committed: $f, must be gitignored, never in the repo"; done
done

# --- ATS is never turned off ----------------------------------------------------------
# The defaults are already right: HTTPS only, TLS 1.2+. Nothing here turns ATS on. This exists
# to catch an app turning it OFF, which is a one-line change nobody would notice in review.
#
# Ask git which files exist rather than grepping a fixed list. A repo with none of them would
# otherwise pass on an empty search, which is the same failure as the old no_emdash and
# delete_path checks (D52, D53). Nothing to check is a failure here, not a pass.
#
# Plists are read with plutil rather than grepped, because the key and its value sit on separate
# lines and a grep for the key alone cannot tell `<true/>` from `<false/>`. The narrower
# NSAllowsArbitraryLoadsInWebContent and ...ForMedia are deliberately NOT flagged: they are
# scoped exceptions with legitimate uses, unlike the blanket switch.
ats_checked=0
ats_bad=0
for f in $(git ls-files '*.plist' 2>/dev/null); do
  ats_checked=$((ats_checked + 1))
  v=$(plutil -extract NSAppTransportSecurity.NSAllowsArbitraryLoads raw -o - "$f" 2>/dev/null)
  if [ "$v" = "true" ]; then
    bad "ATS disabled: $f sets NSAppTransportSecurity.NSAllowsArbitraryLoads = true"
    ats_bad=1
  fi
done
for f in $(git ls-files 'project.yml' '*.xcconfig' 2>/dev/null); do
  ats_checked=$((ats_checked + 1))
  if grep -nE 'NSAllowsArbitraryLoads([^A-Za-z]|$)' "$f" 2>/dev/null | grep -qiE '(true|yes)'; then
    bad "ATS disabled: $f enables NSAllowsArbitraryLoads"
    ats_bad=1
  fi
done
if [ "$ats_checked" -eq 0 ]; then
  # A repo that builds no app has no plist and no ATS setting to turn off. "Nothing to check" is
  # correctly a FAILURE in an app, per D52, and correctly not applicable here. (BOOT-44)
  if [ "$REPO_KIND" != app ]; then na "ATS (no app to configure)"
  else bad "no plist, xcconfig or project.yml is tracked, so ATS could not be checked in anything"; fi
elif [ "$ats_bad" -eq 0 ]; then
  ok "ATS not disabled (checked $ats_checked file(s))"
fi

# --- FD-0005: exactly one release mechanism (Xcode Cloud) --------------------------
if [ -f Makefile ] && grep -qE 'xcodebuild .*-exportArchive|xcodebuild .*archive' Makefile 2>/dev/null; then
  bad "Makefile has a local archive/upload target, release is Xcode Cloud only, that path is retired (0006)"
fi

# FD-0010: a version bump is the trigger for EVERY cloud lane, not only release. So the trigger
# file is required in every app, not only in one that ships. This check used to sit inside the
# release.yml branch, which is why three apps on Xcode Cloud had no trigger file and nothing said so.
if [ "$REPO_KIND" != app ]; then
  na "Config/Version.xcconfig (FD-0010)"
  na "Version.xcconfig wired via configFiles (FD-0010)"
else
[ -f Config/Version.xcconfig ] && ok "Config/Version.xcconfig present, the cloud trigger (FD-0010)" \
  || bad "Config/Version.xcconfig missing. It is what triggers CI and release; without it a bump has nothing to change (FD-0010)."
grep -q "Config/Version.xcconfig" project.yml 2>/dev/null && ok "Version.xcconfig wired via configFiles (FD-0010)" \
  || bad "Config/Version.xcconfig is not in project.yml configFiles, so the build number in it is never read (FD-0010)."
fi
grep -qE '^\s*CURRENT_PROJECT_VERSION:' project.yml 2>/dev/null \
  && bad "CURRENT_PROJECT_VERSION is set in project.yml as well as Config/Version.xcconfig. A target setting wins over the config file, so the trigger file would be decorative. Remove it from project.yml (FD-0010)."
if [ "$REPO_KIND" != app ]; then na "ci_post_clone.sh (FD-0010)"
else
[ -f ci_scripts/ci_post_clone.sh ] && ok "ci_post_clone.sh present (FD-0010)" \
  || bad "ci_scripts/ci_post_clone.sh missing, so Xcode Cloud cannot generate the project (FD-0010)."
fi

# Release is the opt-in half: release.yml marks an app that ships to TestFlight.
if [ -f release.yml ]; then
  ok "release.yml present, this app ships to TestFlight (FD-0005)"
fi

# --- D35: the enforcement layer matches what was installed --------------------------
# The manifest is written by _bootstrap/scripts/install-enforcement.sh and committed. A
# mismatch means a hook, a gate script or settings.json changed outside the install process,
# whoever changed it: an agent that got past the deny rules, another editor, or a bridge that
# is not governed by those rules at all.
#
# WHY A MISSING MANIFEST WARNS RATHER THAN FAILS. Six repos carry hooks and no manifest today.
# Failing here would break `make verify`, and `make verify` is what the finish gate runs every
# turn, so conform would take the gate down in the very repos it exists to protect. Coverage is
# tracked on the compliance board instead, which is built to be loud, and this warning
# disappears repo by repo as the installer reaches them.
# _bootstrap#148: a hook with no execute bit does not run, and the harness treats that as a
# non-blocking error and proceeds. Content hashes cannot see it, because a mode change is not
# content. This is the only check that asks whether the layer can actually RUN.
if [ -f scripts/hook-liveness.sh ]; then
  if _lv=$(bash scripts/hook-liveness.sh 2>&1); then
    ok "every hook can execute, and guard-bash still refuses a blocked command"
  else
    bad "the enforcement layer cannot run. A hook with no execute bit fails open, silently."
    printf '%s\n' "$_lv" | sed 's/^/        /'
  fi
fi

if [ -f .claude/.enforcement-manifest ]; then
  drift=0
  while IFS=' ' read -r want path; do
    case "$want" in ''|'#'*|template=*) continue ;; esac
    [ -n "$path" ] || continue
    if [ ! -f "$path" ]; then
      bad "enforcement file MISSING: $path (recorded in .enforcement-manifest)"; drift=1; continue
    fi
    have=$(git hash-object "$path" 2>/dev/null)
    if [ "$have" != "$want" ]; then
      bad "enforcement file CHANGED since install: $path (D35)"; drift=1
    fi
  done < .claude/.enforcement-manifest
  if [ "$drift" -eq 0 ]; then
    ok "enforcement layer matches its manifest (D35)"
  else
    printf '        %s\n' "Fold the change into _bootstrap/template, then re-install:"
    printf '        %s\n' "  bash ~/Developer/_bootstrap/scripts/install-enforcement.sh ."
  fi
elif [ -d .claude/hooks ]; then
  printf '  \033[33m!\033[0m %s\n' "no .claude/.enforcement-manifest: this repo's hooks are UNMANAGED (D35)"
  printf '        %s\n' "  bash ~/Developer/_bootstrap/scripts/install-enforcement.sh ."
fi

# --- D40/D41/D44: work lives on the GitHub board, never in a file -------------------
# This exists because deleting the files once is not the same as them staying deleted. Every
# one-time cleanup in this factory has decayed. A well-meaning agent reading an old memory or
# an old README will happily write roadmap.md again unless something refuses.
QF=0
for f in roadmap.md inbox.md scramble.md; do
  if [ -e "$f" ]; then
    bad "$f exists. Work lives on this app's GitHub board, never in a file (D40, D41, D44)."
    QF=1
  fi
done
# and nothing may point an agent back at them. .claude/ and .gitignore are excluded: they hold
# deny rules that guard against these files, which is the opposite of recommending them.
# docs/ and backups/ are excluded on purpose: a decision record and an archive are ALLOWED to
# name what was retired. That is history, and rewriting history to match today is its own lie.
# scripts/ is excluded because the script that deletes these files has to name them.
QREF=$(grep -rIl --exclude-dir=.git --exclude-dir=.claude --exclude-dir=node_modules \
        --exclude-dir=docs --exclude-dir=backups --exclude-dir=scripts \
        --exclude=.gitignore --exclude='QA-BASELINE-*' \
        -e 'roadmap\.md' -e 'inbox\.md' -e 'scramble\.md' \
        . 2>/dev/null | sed 's|^\./||' | tr '\n' ' ')
if [ -n "$QREF" ]; then
  bad "these still tell an agent to use a queue file: $QREF"
  printf '        %s\n' "Point them at the app's GitHub board instead (D39)."
  QF=1
fi
[ "$QF" -eq 0 ] && ok "no queue file, and nothing points at one (D39, D40, D41, D44)"

# --- FD-0000: the vendored factory ADR set is read-only; a local edit is drift ------
# The FD- set is copied into every repo and must stay byte-identical to the factory's.
# .factory-checksum is the hash recomputed here; a mismatch means a vendored decision was
# edited locally, which silently forks the factory. Absent means not migrated yet (the
# compliance board tracks that), so it warns rather than failing the gate.
FACDIR="docs/decisions/factory"
if [ -f "$FACDIR/.factory-checksum" ]; then
  want=$(cat "$FACDIR/.factory-checksum")
  have=$(find "$FACDIR" -name 'FD-*.md' | LC_ALL=C sort | xargs cat | shasum -a 256 | cut -d' ' -f1)
  if [ "$want" != "$have" ]; then
    bad "vendored FD- set edited locally (factory checksum mismatch). Fix: run 'git checkout docs/decisions/factory' to drop the local edit, or 'bash ~/Developer/_bootstrap/scripts/vendor-factory.sh' to re-vendor the current set from the factory."
  else
    ok "vendored FD- set matches the factory checksum (FD-0000)"
  fi
else
  printf '  %s\n' "note: no docs/decisions/factory/.factory-checksum yet (repo not migrated to FD-/AD-)"
fi

# --- The issue forms are generated, so a hand edit is drift ------------------------
# One field definition feeds both the GitHub forms and make-board-ticket.sh's validator, which
# has read it since BOOT-26. Two
# hand written copies drift silently: a label typo breaks the form and the parser in the same
# moment and neither says so. Regenerating and diffing here is what makes that impossible
# rather than merely discouraged.
#
# Absent source PRINTS A NOTE rather than passing quietly. A check that says nothing when the
# thing it guards is missing is indistinguishable from a check that passed, which is the exact
# failure this factory keeps rediscovering.
IFSRC=".github/issue-fields.psv"
if [ ! -f "$IFSRC" ]; then
  printf '  %s\n' "note: no $IFSRC yet (repo not vendored with the issue forms)"
elif [ ! -f scripts/gen-issue-forms.sh ]; then
  bad "$IFSRC exists but scripts/gen-issue-forms.sh does not, so the forms cannot be checked. Fix: bash ~/Developer/_bootstrap/scripts/vendor-factory.sh"
elif [ ! -d .github/ISSUE_TEMPLATE ]; then
  bad "$IFSRC exists but .github/ISSUE_TEMPLATE does not. Fix: bash scripts/gen-issue-forms.sh"
else
  IFTMP=$(mktemp -d)
  if [ -z "$IFTMP" ] || [ ! -d "$IFTMP" ]; then
    bad "could not make a temp dir to regenerate the issue forms, so they were NOT checked."
  elif ! bash scripts/gen-issue-forms.sh "$IFTMP" >/dev/null 2>&1; then
    bad "scripts/gen-issue-forms.sh failed, so the issue forms were NOT checked. Run it directly to see why: bash scripts/gen-issue-forms.sh"
    rm -rf "$IFTMP"
  else
    IFDIFF=$(diff -r .github/ISSUE_TEMPLATE "$IFTMP" 2>&1)
    if [ -n "$IFDIFF" ]; then
      bad "the issue forms no longer match $IFSRC. They are generated; edit the source, not the .yml. Fix: sh scripts/gen-issue-forms.sh"
      IFN=$(printf '%s\n' "$IFDIFF" | wc -l | tr -d ' ')
      printf '%s\n' "$IFDIFF" | head -20 | sed 's/^/        /'
      # A truncated diff that does not say it was truncated reads as the whole story, and the
      # operator fixes one file believing it was the only one (FD-0013).
      [ "$IFN" -gt 20 ] && printf '        ... and %s more diff lines across the other files\n' "$((IFN-20))"
    else
      ok "issue forms match $IFSRC (generated, never hand written)"
    fi
    rm -rf "$IFTMP"
  fi
fi


# The explanation lock and gate_fix_instructions (FD-0013, _bootstrap#4).
#
# WHY THIS IS HERE AND NOT ONLY IN A TEST. explain-lock.mjs's own header calls
# `node scripts/explain-lock.mjs --check` "the gate", and nothing ran it. tests/fix-instructions.test.sh
# asserts the fix/verify half against the real explanations, so that half was gated. The hash half,
# which is what explain-lock was built for, was gated by nothing: no test asserts drifted, unlocked,
# orphan or missing. Demonstrated on 2026-08-16 by adding a comment inside one check's slice, which
# changes the hash and no behaviour: explain-lock --check exited 1 and `make verify` stayed green at
# 567 assertions. no_secrets had also sat drifted since _bootstrap#120 with every run green.
#
# Runs only where the scanner lives. conform.sh is vendored into every app repo, and the
# explanations, the lock and explain-lock.mjs are _bootstrap's alone, so an app repo skips this
# rather than reporting an absent file as a failure.
if [ -f scripts/explain-lock.mjs ] && [ -f scripts/compliance-explain.mjs ]; then
  if _el=$(node scripts/explain-lock.mjs --check 2>&1); then
    ok "every check explanation matches its code, and every fix/verify instruction resolves"
  else
    bad "an explanation has drifted from the code it explains, or a fix/verify instruction does not resolve. Re-read the explanation against the code, then re-lock: node scripts/explain-lock.mjs --write"
    printf '%s\n' "$_el" | sed 's/^/        /'
  fi
fi
if [ "$fail" -ne 0 ]; then echo "conform: FAILED (see ✗ above)"; exit 1; fi
echo "conform: green"
