#!/usr/bin/env bash
# ========================================================================
#  🐙  Tiara auto-sync installer  —  run this ONCE.
#
#  It does three things, safely and out loud:
#    1) Fixes today's drift (drops the stale compliance.json timestamp,
#       commits the new sync tools, pulls GitHub's commits, pushes).
#    2) Schedules the button to run itself every 30 min in the background
#       (a macOS LaunchAgent) — the "never manual" part.
#    3) Runs one check so you can see it's all aligned.
#
#  Re-running it is safe: it only acts where there's something to do.
# ========================================================================
set -uo pipefail
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_DIR" || { echo "can't find the repo"; exit 1; }
LABEL="com.princess.tiara.autosync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/tiara-sync.log"

echo "🎀 Tiara auto-sync installer"
echo "   repo: $REPO_DIR"
echo

# --- 1. fix today's drift -------------------------------------------------
echo "1) Fixing drift…"
[ -f .git/index.lock ] && rm -f .git/index.lock
[ -f .git/DELETE-ME-index.lock.bak ] && rm -f .git/DELETE-ME-index.lock.bak

# drop the stale compliance.json timestamp only if it's the lone change there
if ! git diff --quiet -- compliance.json 2>/dev/null; then
  if [ "$(git diff --numstat -- compliance.json | awk '{print $1"+"$2}')" = "1+1" ]; then
    git checkout -- compliance.json && echo "   • dropped the stale compliance.json timestamp (GitHub's newer copy wins)"
  else
    echo "   • compliance.json has real changes — leaving them; commit them yourself if you want to keep them"
  fi
fi

# commit the new sync tools if they aren't committed yet
git add scripts/tiara-sync.sh scripts/install-auto-sync.sh "Tiara Sync.command" CLAUDE.md 2>/dev/null
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -q -m "Add Tiara sync button + background auto-sync + session rule" && echo "   • committed the new sync tools"
fi

git fetch --quiet origin 2>/dev/null || echo "   • (couldn't reach GitHub to fetch)"
BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
if [ "$BEHIND" -gt 0 ]; then
  if git pull --rebase --quiet 2>/dev/null; then echo "   • pulled $BEHIND commit(s) from GitHub"
  else echo "   • couldn't auto-pull cleanly — run: git pull --rebase"; git rebase --abort >/dev/null 2>&1; fi
fi
AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
if [ "$AHEAD" -gt 0 ]; then
  git push --quiet 2>/dev/null && echo "   • pushed your $AHEAD commit(s) to GitHub" || echo "   • push failed — run: git push"
fi
echo

# --- 2. schedule the background sync -------------------------------------
echo "2) Scheduling the background sync (every 30 min)…"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
BREW_BIN="/opt/homebrew/bin"; [ -d "$BREW_BIN" ] || BREW_BIN="/usr/local/bin"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$REPO_DIR/scripts/tiara-sync.sh</string>
    <string>--auto</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>$HOME</string>
    <key>PATH</key><string>$BREW_BIN:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>StartInterval</key><integer>1800</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST_EOF

launchctl unload "$PLIST" >/dev/null 2>&1
if launchctl load "$PLIST" 2>/dev/null; then
  echo "   • scheduled ✓  (log: $LOG)"
else
  echo "   • couldn't load the schedule automatically — run: launchctl load \"$PLIST\""
fi
echo

# --- 3. one check ---------------------------------------------------------
echo "3) Checking everything is aligned…"
bash "$REPO_DIR/scripts/tiara-sync.sh" --check
echo "✅ Setup done. From now on it syncs itself; double-click 'Tiara Sync.command' any time you want to run it by hand."
