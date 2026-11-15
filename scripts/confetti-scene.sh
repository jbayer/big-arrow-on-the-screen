#!/bin/bash
# The README's confetti scene: the neutral backdrop (desktop, menu bar and Dock covered) with an
# "all checks passed" dialog, a green arrow at Merge with --confetti, one screenshot mid-rain.
# Run it on the test Mac: scripts/arthur-gui.sh 'scripts/confetti-scene.sh /tmp/confetti.png'
# Usage: scripts/confetti-scene.sh <out.png> [bigarrow binary]
set -euo pipefail
OUT="$1"
BIN="${2:-.build/debug/bigarrow}"
WORK=$(mktemp -d)
swiftc -O scripts/backdrop.swift -o "$WORK/backdrop"
"$WORK/backdrop" --cover --title "Pull request #76" --message "All 147 checks passed. Ready to merge." \
  --buttons "Close,Merge" --x 460 --y 300 & BACKDROP=$!
trap 'kill "$BACKDROP" 2>/dev/null; "$BIN" stop --all > /dev/null 2>&1 || true' EXIT
sleep 2.5
# The cover counts as covering the dialog, so an arrow bound with --app would hide: find the
# button with a dry run, then point at its centre unbound.
AT=$("$BIN" point --element Merge --role button --app backdrop --text x --dry-run --json \
  | python3 -I -c 'import json, sys; t = json.load(sys.stdin)["target"]; print(f"{round(t["x"])},{round(t["y"])}")')
"$BIN" start --at "$AT" --color green \
  --text "Franz, all green: merge it" --confetti --duration 8 > /dev/null
sleep 1.8
screencapture -x "$OUT"
echo "wrote $OUT"
