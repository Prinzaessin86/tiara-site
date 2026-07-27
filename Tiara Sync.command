#!/usr/bin/env bash
# 🐙 Double-click me to sync the Tiara board.
# Opens Terminal, runs the normal (interactive) button, then waits so you can read it.
HERE=$(cd "$(dirname "$0")" && pwd)
bash "$HERE/scripts/tiara-sync.sh"
echo
echo "— done — press any key to close this window —"
read -n 1 -s
