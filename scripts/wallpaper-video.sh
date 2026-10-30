#!/bin/bash
# The README video: an agent walks a human through the most complained-about Mac setting since
# 2023, "Click wallpaper to show desktop" in Desktop & Dock, with real bigarrow arrows and real
# clicks (glided like a hand, so you can follow the pointer). Records the whole main display.
# Run on the test Mac (Arthur, lid closed: one 1920x1080 display), never on a desk in use.
# Nothing personal on screen: other apps, the Dock and desktop widgets are hidden, Finder windows
# are closed (and reopened on exit), the two demo windows are TextEdit files in a temporary
# folder, and System Settings' sidebar is scrolled past the Apple Account row before the
# recording starts. The setting is put back to what it was on exit.
# Usage: scripts/wallpaper-video.sh <out-dir>   -> wallpaper.mp4, wallpaper.gif
set -uo pipefail
OUT="$1"
BIN=.build/release/bigarrow
APP="System Settings"
WORK=$(cd "$(mktemp -d /tmp/wallpaper-video.XXXXXX)" && pwd -P)
mkdir -p "$OUT"
swiftc -O scripts/testkit.swift -o "$WORK/testkit" || exit 1
KIT="$WORK/testkit"
DOCK_AUTOHIDE=$(defaults read com.apple.dock autohide 2>/dev/null || echo 0)
WIDGETS_HIDDEN=$(defaults read com.apple.WindowManager StandardHideWidgets 2>/dev/null || echo 0)
CLICK_SHOWS=$(defaults read com.apple.WindowManager EnableStandardClickToShowDesktop 2>/dev/null || echo 1)
FINDER_TARGETS=$(osascript <<'AS'
set out to ""
tell application "Finder" to repeat with w in Finder windows
  try
    set out to out & POSIX path of (target of w as alias) & linefeed
  end try
end repeat
return out
AS
)
RECORDER=""; MINIMIZED=""
# Pixelated in the video, as "<from s> <to s> x y w h" lines: the Apple menu's "Log Out <name>..."
# row while the menu is open, and the desktop widgets (weather with a location) while revealed.
BLUR="$WORK/blur.txt"; : > "$BLUR"
WIDGETS="10 40 355 355"
since() { python3 -c "import time; print(round(time.time() - $START, 2))"; }

cleanup() {
  $BIN stop --all > /dev/null 2>&1
  [ -n "$RECORDER" ] && { kill -INT "$RECORDER" 2>/dev/null; wait "$RECORDER" 2>/dev/null; }
  osascript -e "tell application \"TextEdit\" to close (every document whose path starts with \"$WORK\") saving no" > /dev/null 2>&1
  osascript -e "tell application \"$APP\" to quit" > /dev/null 2>&1
  defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool "$([ "$CLICK_SHOWS" = 1 ] && echo true || echo false)"
  defaults write com.apple.dock autohide -int "$DOCK_AUTOHIDE"; killall Dock
  defaults write com.apple.WindowManager StandardHideWidgets -int "$WIDGETS_HIDDEN"
  [ -n "$MINIMIZED" ] && osascript -e 'tell application "System Events" to tell process "TextEdit" to set value of attribute "AXMinimized" of every window to false' > /dev/null 2>&1
  local target
  while IFS= read -r target; do [ -n "$target" ] && open "$target"; done <<< "$FINDER_TARGETS"
}
trap cleanup EXIT

# center <label> [role] [app]: the middle x y of the first element with that label (and role).
center() {
  $BIN elements --app "${3:-$APP}" --match "$1" --json | python3 -c 'import json, sys
role = sys.argv[1]
hits = [n for n in json.load(sys.stdin) if n.get("frame") and (not role or n["role"] == role)]
(x, y), (w, h) = hits[0]["frame"]
print(round(x + w / 2), round(y + h / 2))' "${2:-}"
}
# frame_of <label> [role] [app]: the x,y,w,h of the first element with that label (and role).
frame_of() {
  $BIN elements --app "${3:-$APP}" --match "$1" --json | python3 -c 'import json, sys
role = sys.argv[1]
hits = [n for n in json.load(sys.stdin) if n.get("frame") and (not role or n["role"] == role)]
(x, y), (w, h) = hits[0]["frame"]
print(f"{x:.0f},{y:.0f},{w:.0f},{h:.0f}")' "${2:-}"
}
# hand <x> <y>: glide there like a hand, then click; CLICKED is the click's time for the blur log.
hand() { $KIT glide "$1" "$2" 0.8; sleep 0.25; CLICKED=$(since); $KIT click "$1" "$2"; }
plus() { python3 -c "print(round($1 + $2, 2))"; }
# say_it <seconds> <bigarrow start options...>: one arrow, held, then removed.
say_it() {
  local hold="$1"; shift
  $BIN start "$@" > /dev/null || { echo "arrow failed: $*" >&2; exit 1; }
  sleep "$hold"
  $BIN stop --all > /dev/null
}
window_frame() { osascript -e "tell application \"System Events\" to tell process \"$1\" to get {position, size} of window 1" | tr -d ' '; }

# --- Stage: nothing but two harmless windows on the wallpaper. ---
defaults write com.apple.dock autohide -bool true; killall Dock
defaults write com.apple.WindowManager StandardHideWidgets -bool true
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool true
osascript -e 'tell application "Finder" to close every Finder window'
# Finder also unhides its Settings window when it becomes active (a wallpaper click does that).
osascript -e 'tell application "Finder" to activate' > /dev/null; sleep 0.5
osascript > /dev/null <<'AS'
tell application "System Events" to tell process "Finder"
  repeat with w in windows
    try
      click (first button of w whose subrole is "AXCloseButton")
    end try
  end repeat
end tell
AS
printf 'Shopping list\n\nBread\nMilk\nApples\nCoffee\nBirthday card for Grandpa\n' > "$WORK/Shopping list.txt"
printf 'Weekend\n\nWater the tomatoes\nCall the plumber\nFinally fix that one Mac setting\n' > "$WORK/Weekend.txt"
open -a TextEdit "$WORK/Shopping list.txt" "$WORK/Weekend.txt"; sleep 2
# Any other TextEdit window (an untitled scratch file) is minimized for the recording.
MINIMIZED=1
osascript -e 'tell application "System Events" to tell process "TextEdit" to set value of attribute "AXMinimized" of (every window whose name is not "Shopping list.txt" and name is not "Weekend.txt") to true' > /dev/null 2>&1

# System Settings opens on General, sidebar scrolled so Desktop & Dock is in view and the
# Apple Account row is not, then hidden: the Apple menu brings back exactly this window.
open "x-apple.systempreferences:com.apple.systempreferences.GeneralSettings"; sleep 2.5
osascript -e "tell application \"System Events\" to tell process \"$APP\" to set size of window 1 to {760, 640}" \
  -e "tell application \"System Events\" to tell process \"$APP\" to set position of window 1 to {980, 150}" > /dev/null
sleep 0.8
read -r sx sy <<< "$(center "Desktop & Dock" AXButton)"
for _ in $(seq 30); do
  # Both "Apple Account" rows (the name, the suggestions) must sit above the sidebar's top edge.
  account=$($BIN elements --app "$APP" --json | python3 -c 'import json, sys
nodes = [n for n in json.load(sys.stdin) if n.get("frame")]
top = next(n["frame"][0][1] for n in nodes if n["role"] == "AXOutline")
rows = [n["frame"] for n in nodes if "Apple Account" in (n.get("label") or "")]
print(1 if not rows or max(y + h for (x, y), (w, h) in rows) > top - 4 else 0)')
  [ "$account" = 0 ] && break
  $KIT scroll "$sx" 500 1; sleep 0.2
done
osascript -e "tell application \"System Events\" to set visible of process \"$APP\" to false"
osascript -e 'tell application "System Events" to set visible of every process whose visible is true and name is not "TextEdit" to false'
osascript -e 'tell application "TextEdit" to activate'
$KIT move-window TextEdit 260 260 2>/dev/null
osascript -e 'tell application "System Events" to tell process "TextEdit" to set position of window 2 to {700, 420}' > /dev/null
$KIT glide 1500 900 0.3; sleep 1.5

# --- Record. ---
# ffmpeg, not screencapture -v: an interrupted screencapture drops the whole file.
ffmpeg -loglevel error -y -f avfoundation -pixel_format uyvy422 -capture_cursor 1 -capture_mouse_clicks 1 \
  -framerate 30 -i "Capture screen 0:none" -c:v libx264 -preset ultrafast -crf 16 "$WORK/raw.mp4" < /dev/null &
RECORDER=$!
START=$(python3 -c 'import time; print(time.time())')
sleep 1.5

# The problem: one click on the wallpaper and every window runs for the edges.
say_it 2.8 --at 1500,780 --text "Watch. One innocent click on the wallpaper..." --color purple --shape spiral --from left
hand 1500 780; T0=$CLICKED; sleep 1.2
say_it 3 --at 1880,560 --text "...and every window flees. Since 2023." --color orange --shape zigzag --from left --size L
hand 1500 780; sleep 1.2
echo "$T0 $(plus "$CLICKED" 1.0) $WIDGETS" >> "$BLUR"

# 1. The Apple menu.
say_it 2.5 --at 24,14 --text "1. The apple. Yes, the fruit." --color red --size S --from bottom-right
hand 24 14; T0=$CLICKED; sleep 0.8
# 2. System Settings in the Apple menu (it belongs to the frontmost app, Finder after the clicks).
ITEM=$(frame_of _systemSettingsRequested AXMenuItem "$($KIT frontmost)")
[ -n "$ITEM" ] || { echo "the Apple menu did not open" >&2; exit 1; }
IFS=, read -r ix iy iw ih <<< "$ITEM"; mx=$((ix + iw / 3)); my=$((iy + ih / 2))
LOGOUT=$($BIN elements --app "$($KIT frontmost)" --match "Log Out" --json | python3 -c 'import json, sys
(x, y), (w, h) = json.load(sys.stdin)[0]["frame"]
print(f"{x:.0f} {y:.0f} {w:.0f} {h:.0f}")')
say_it 2.5 --rect "$ITEM" --text "2. System Settings. Where settings go to hide." --style box --color blue --from right
# Straight down first: crossing the menu bar with a menu open would switch to Finder's menu.
$KIT glide 24 "$my" 0.5; hand "$mx" "$my"; sleep 0.4
echo "$T0 $(plus "$CLICKED" 0.6) $LOGOUT" >> "$BLUR"
sleep 1.4
# 3. Desktop & Dock in the sidebar.
read -r dx dy <<< "$(center "Desktop & Dock" AXButton)"
say_it 3 --element "Desktop & Dock" --role button --app "$APP" --no-raise \
  --text "3. Desktop & Dock. Not Wallpaper. Not Displays. This one." --style ring --color teal --from left
hand "$dx" "$dy"; sleep 1.5
# 4. Scroll the pane down to the setting.
IFS=, read -r wx wy ww wh <<< "$(window_frame "$APP")"
say_it 2.5 --at "$((wx + ww * 2 / 3)),$((wy + wh - 60))" --text "4. Scroll. Further. It's always further." \
  --color yellow --shape zigzag --from left
for _ in $(seq 40); do
  read -r px py <<< "$(center click-wallpaper-to-reveal-desktop AXPopUpButton)"
  [ "$py" -lt $((wy + wh - 90)) ] && break
  $KIT scroll "$((wx + ww * 2 / 3))" "$((wy + wh / 2))" 1; sleep 0.12
done
sleep 0.8
# 5. The popup, named after the thing it does not seem to do.
read -r px py <<< "$(center click-wallpaper-to-reveal-desktop AXPopUpButton)"
say_it 3.2 --element click-wallpaper-to-reveal-desktop --app "$APP" --no-raise \
  --text "5. 'Show desktop'. Nothing to do with Stage Manager." --style box --corners sharp --color green \
  --border white-black --from left
hand "$px" "$py"; sleep 1
# 6. The menu: "Only in Stage Manager" is how you say "off".
read -r ox oy <<< "$(center "Only in Stage Manager" AXMenuItem)"
say_it 3.2 --at "$ox,$oy" --text "6. 'Only in Stage Manager' means 'off'. Obviously." --color pink --from left --close-button
hand "$ox" "$oy"; sleep 1.2

# Proof: the same click, nothing runs away.
osascript -e "tell application \"System Events\" to set visible of process \"$APP\" to false"; sleep 0.8
say_it 2.5 --at 1500,780 --text "Now click the wallpaper..." --color purple --shape spiral --from left
hand 1500 780; sleep 1.2
say_it 3.5 --at 1500,780 --text "Nothing happens. Bliss." --color "#34C759" --size L --shape straight --from left
sleep 0.5
END=$(python3 -c 'import time; print(time.time())')
kill -INT "$RECORDER" 2>/dev/null; wait "$RECORDER" 2>/dev/null; RECORDER=""
echo "scene took $(python3 -c "print(round($END - $START, 1))") s"

# --- Encode: the logged areas pixelated (0.3 s margin either side), then MP4 for the link and GIF for the README. ---
# The recorder's first frame comes a moment after START: shift every time by that lag.
LAG=$(python3 -c "print(max(0, $END - $START - $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$WORK/raw.mp4")))")
echo "recorder lag: $LAG s"
FILTER=$(python3 - "$BLUR" "$LAG" <<'PY'
import sys
lag = float(sys.argv[2])
areas = [l.split() for l in open(sys.argv[1]) if l.strip()]
parts, last = [f"[0:v]split={len(areas) + 1}[v0]" + "".join(f"[c{i}]" for i in range(len(areas)))], "v0"
for i, (start, stop, *rect) in enumerate(areas):
    x, y, w, h = (int(float(v)) for v in rect)
    x, y, w, h = max(x - 4, 0), max(y - 4, 0), w + 8, h + 8
    # Pixelated to blocks of 16: unreadable at any size, unlike a box blur on a 32 px row.
    parts.append(f"[c{i}]crop={w}:{h}:{x}:{y},scale={max(w // 16, 1)}:{max(h // 16, 1)},scale={w}:{h}:flags=neighbor[b{i}]")
    parts.append(f"[{last}][b{i}]overlay={x}:{y}:enable='between(t,{float(start) - lag - 0.3:.2f},{float(stop) - lag + 0.3:.2f})'[v{i + 1}]")
    last = f"v{i + 1}"
print(";".join(parts) + f";[{last}]null")
PY
) || exit 1
echo "blur: $FILTER"
ffmpeg -loglevel error -y -i "$WORK/raw.mp4" -filter_complex "$FILTER" -c:v libx264 -crf 24 -preset slow \
  -pix_fmt yuv420p -movflags +faststart -an "$WORK/clean.mp4" || exit 1
ffmpeg -loglevel error -y -i "$WORK/clean.mp4" -vf "scale=1280:-2" -c:v libx264 -crf 26 -preset slow \
  -pix_fmt yuv420p -movflags +faststart -an "$OUT/wallpaper.mp4" || exit 1
ffmpeg -loglevel error -y -i "$WORK/clean.mp4" -vf "fps=10,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
  "$OUT/wallpaper.gif" || exit 1
cp "$WORK/clean.mp4" "$OUT/full.mp4"
ls -la "$OUT"
