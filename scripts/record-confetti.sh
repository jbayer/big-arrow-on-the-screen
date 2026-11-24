#!/bin/bash
# Records the README confetti video: the neutral backdrop (desktop, menu bar and Dock covered) with
# an "all checks passed" dialog, then a green arrow at Merge with --confetti over the whole screen.
# Writes confetti.mp4 and confetti.gif. Needs ffmpeg and Screen Recording; run it on the test Mac:
#   scripts/arthur-gui.sh 'scripts/record-confetti.sh /tmp/confetti-video'
# Usage: scripts/record-confetti.sh <out-dir> [bigarrow binary]
set -euo pipefail
OUT="$1"
BIN="${2:-.build/release/bigarrow}"
mkdir -p "$OUT"
swiftc -O scripts/backdrop.swift -o "$OUT/backdrop"
"$OUT/backdrop" --cover --title "Pull request #76" --message "All 147 checks passed. Ready to merge." \
  --buttons "Close,Merge" --x 460 --y 300 & BACKDROP=$!
trap 'kill "$BACKDROP" 2>/dev/null || true; "$BIN" stop --all > /dev/null 2>&1 || true' EXIT
sleep 2.5
# The cover counts as covering the dialog, so an arrow bound with --app would hide: find the
# button with a dry run, then point at its centre unbound.
AT=$("$BIN" point --element Merge --role button --app backdrop --text x --dry-run --json \
  | python3 -I -c 'import json, sys; t = json.load(sys.stdin)["target"]; print(f"{round(t["x"])},{round(t["y"])}")')
screencapture -v -V 8 -x "$OUT/confetti.mov" & RECORDER=$!
sleep 1
"$BIN" start --at "$AT" --color green --text "Franz, all green: merge it" --confetti --duration 6 > /dev/null
wait "$RECORDER"
ffmpeg -loglevel error -y -i "$OUT/confetti.mov" -vf "scale=1280:-2:flags=lanczos" \
  -c:v libx264 -pix_fmt yuv420p -crf 26 -movflags +faststart -an "$OUT/confetti.mp4"
ffmpeg -loglevel error -y -i "$OUT/confetti.mov" \
  -vf "fps=15,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
  "$OUT/confetti.gif"
ls -la "$OUT/confetti.mp4" "$OUT/confetti.gif"
