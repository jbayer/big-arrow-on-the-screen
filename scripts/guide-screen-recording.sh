#!/bin/bash
# Screenshots for docs/guides/allow-screen-recording, one real bigarrow arrow per step, captured
# at Retina resolution around System Settings and the sign. Run on the test Mac (Arthur), never
# on a desk in use.
# Steps 1-4 only point. Step 5 shows the real password sheet: the script presses the switch of
# an entry that is off and harmless (python3.14), shoots the sheet, presses Cancel and checks
# that the switch is off again. It never types a password and never leaves a permission changed.
# Nothing personal: the sidebar's first row (the Apple Account name) is either off the left edge
# of the screen or scrolled out of view, and the shot of the password sheet starts below its
# user-name field. Other apps, the Dock and desktop widgets are hidden for the shots; the Dock,
# the widgets and the window's frame are restored on exit.
# Usage: scripts/guide-screen-recording.sh <out-dir>
set -uo pipefail
OUT="$1"
BIN=.build/release/bigarrow
APP="System Settings"
HARMLESS=python3.14_Toggle
WORK=$(mktemp -d)
mkdir -p "$OUT"
swiftc -O scripts/testkit.swift -o "$WORK/testkit" || exit 1
swiftc -O scripts/settings-ax.swift -o "$WORK/settings-ax" || exit 1
KIT="$WORK/testkit"; AX="$WORK/settings-ax"
DOCK_AUTOHIDE=$(defaults read com.apple.dock autohide 2>/dev/null || echo 0)
WIDGETS_HIDDEN=$(defaults read com.apple.WindowManager StandardHideWidgets 2>/dev/null || echo 0)
FRAME=""; PRESSED=""

# frame: the window's x,y,w,h (read again until System Settings answers with all four).
frame() {
  local value
  for _ in 1 2 3 4 5; do
    value=$(osascript -e "tell application \"System Events\" to tell process \"$APP\" to get {position, size} of window 1" | tr -d ' ')
    [ "$(tr -cd ',' <<< "$value" | wc -c)" -eq 3 ] && { echo "$value"; return; }
    sleep 0.5
  done
  echo "could not read the System Settings window frame" >&2; exit 1
}
# place <x> <y> <w> <h>: size first, or macOS moves the window to keep the old size on screen.
place() {
  osascript -e "tell application \"System Events\" to tell process \"$APP\" to set size of window 1 to {$3, $4}" \
    -e "tell application \"System Events\" to tell process \"$APP\" to set position of window 1 to {$1, $2}" > /dev/null
  sleep 0.8
}
# pane <deep link id> <expected window title>: opens it from General, so it never stays on a subpage.
pane() {
  open "x-apple.systempreferences:com.apple.systempreferences.GeneralSettings"; sleep 1.5
  [ "$1" = GeneralSettings ] || { open "x-apple.systempreferences:$1"; sleep 2.5; }
  local title
  title=$(osascript -e "tell application \"System Events\" to tell process \"$APP\" to get name of window 1")
  [ "$title" = "$2" ] || { echo "deep link $1 opened '$title', not '$2'" >&2; exit 1; }
}
# element <label> <role>: the frame x,y,w,h of the first element with that label and role.
element() {
  $BIN elements --app "$APP" --match "$1" --json | python3 -c 'import json, sys
hits = [n for n in json.load(sys.stdin) if n["role"] == sys.argv[1] and n.get("frame")]
(x, y), (w, h) = hits[0]["frame"]
print(f"{x:.0f},{y:.0f},{w:.0f},{h:.0f}")' "$2" 2>/dev/null
}
click_center() { local x y w h; IFS=, read -r x y w h <<< "$1"; $KIT click $((x + w / 2)) $((y + h / 2)); }
# undo_press: cancels a password sheet the script opened and makes sure the switch is off again.
undo_press() {
  [ -n "$PRESSED" ] || return 0
  local cancel; cancel=$(element Cancel AXButton)
  [ -n "$cancel" ] && { click_center "$cancel"; sleep 1.5; }
  [ "$($AX value $HARMLESS)" = 0 ] || { $AX press $HARMLESS; sleep 1.5; }
  [ "$($AX value $HARMLESS)" = 0 ] || { echo "WARNING: $HARMLESS is still on, switch it off by hand" >&2; return 1; }
  PRESSED=""
}
cleanup() {
  $BIN stop --all > /dev/null 2>&1
  undo_press
  [ -n "$FRAME" ] && place ${FRAME//,/ }
  defaults write com.apple.dock autohide -int "$DOCK_AUTOHIDE"; killall Dock
  defaults write com.apple.WindowManager StandardHideWidgets -int "$WIDGETS_HIDDEN"
}
trap cleanup EXIT

# shot <name> <x,y,w,h to show> <min top> <bigarrow start options...>: one arrow, one shot of the
# given rect and the sign, 32 pt around them, never above <min top> or the menu bar.
shot() {
  local name="$1" rect="$2" min_top="$3" result region; shift 3
  result=$($BIN start --app "$APP" "$@" --no-animation --json) || { echo "shot $name failed" >&2; exit 1; }
  sleep 1.2
  region=$(python3 - "$result" "$rect" "$min_top" <<'PY'
import json, sys
sx, sy, sw, sh = json.loads(sys.argv[1])["sign"]
x, y, w, h = (float(v) for v in sys.argv[2].split(","))
left = max(min(x, sx) - 32, 0)
top = max(min(y, sy) - 32, 34, float(sys.argv[3]))
right = min(max(x + w, sx + sw) + 32, 1470)
bottom = min(max(y + h, sy + sh) + 32, 956)
print(f"{left:.0f},{top:.0f},{right - left:.0f},{bottom - top:.0f}")
PY
)
  screencapture -x -R "$region" "$WORK/$name.png"
  $BIN stop --all > /dev/null
  # 256 colours, then smaller until the file is under 700 KB.
  python3 - "$WORK/$name.png" "$OUT/$name.png" <<'PY'
import os, sys
from PIL import Image
image = Image.open(sys.argv[1]).convert("RGB")
while True:
    image.quantize(256, method=Image.Quantize.MEDIANCUT, kmeans=2).save(sys.argv[2], optimize=True)
    if os.path.getsize(sys.argv[2]) < 700_000:
        break
    image = image.resize((int(image.width * 0.85), int(image.height * 0.85)), Image.LANCZOS)
PY
  echo "$name: $region"
}

defaults write com.apple.dock autohide -bool true; killall Dock
defaults write com.apple.WindowManager StandardHideWidgets -bool true
pane GeneralSettings ""
osascript -e "tell application \"System Events\" to set visible of every process whose visible is true and name is not \"$APP\" to false"
FRAME=$(frame)

# 1. The manual way, as Apple describes it: Privacy & Security in the sidebar (scrolled so the
#    account row is out of view), from another pane.
# The window's right edge is off the screen: that leaves room for the sign left of the sidebar.
place 760 150 754 625; $AX sidebar-end; sleep 0.5
shot 1-privacy-security "$(frame)" 0 --text "1. Click Privacy & Security" \
  --element "Privacy & Security" --role button --from left
# 2. The Privacy & Security page, scrolled to the Screen & System Audio Recording row.
pane com.apple.preference.security "Privacy & Security"
place -250 150 754 625; $AX reveal "Screen & System Audio Recording"; sleep 0.5
shot 2-screen-recording "$(frame)" 0 --text "2. Click Screen & System Audio Recording" \
  --element "Screen & System Audio Recording" --role button --from right
# 3. The switch, on the pane an agent opens directly by deep link.
pane "com.apple.preference.security?Privacy_ScreenCapture" "Screen & System Audio Recording"
place -250 150 754 625
shot 3-switch-on "$(frame)" 0 --text "Chrome's switch: on means Chrome may record your screen" \
  --element "Google Chrome_Toggle" --from right
# 4. The window ends just below the list, so the arrow comes up from below without crossing the
#    "System Audio Recording Only" heading.
place 60 40 754 580; $AX sidebar-end; sleep 0.5
shot 4-add-app "$(frame)" 0 --text "Chrome missing? Click +" --element Add --from bottom
# 5. The real password sheet: press an off, harmless switch, shoot, Cancel, check it is off.
place 716 150 754 625; $AX sidebar-end; sleep 0.5
[ "$($AX value $HARMLESS)" = 0 ] || { echo "$HARMLESS is not off; not touching it" >&2; exit 1; }
$AX press $HARMLESS; PRESSED=1
password=""
for _ in $(seq 20); do password=$(element Password AXTextField); [ -n "$password" ] && break; sleep 0.5; done
[ -n "$password" ] || { echo "no password sheet appeared after pressing $HARMLESS" >&2; exit 1; }
read -r sheet top <<< "$($BIN elements --app "$APP" --json | python3 -c 'import json, sys
px, py, pw, ph = (float(v) for v in sys.argv[1].split(","))
nodes = [n for n in json.load(sys.stdin) if n.get("frame")]
fields = [n["frame"] for n in nodes if n["role"] == "AXTextField" and abs(n["frame"][0][0] - px) <= 4 and n["frame"][0][1] < py]
cancel = max((n["frame"] for n in nodes if n["role"] == "AXButton" and "Cancel" in (n.get("title"), n.get("label"))), key=lambda f: f[0][1])
user_bottom = max(f[0][1] + f[1][1] for f in fields)
wx, wy, ww, wh = (float(v) for v in sys.argv[2].split(","))
bottom = max(cancel[0][1] + cancel[1][1] + 16, wy + wh)
left, right = min(px - 16, wx), max(px + pw + 16, wx + ww)
print(f"{left:.0f},{user_bottom:.0f},{right - left:.0f},{bottom - user_bottom:.0f} {user_bottom - 2:.0f}")' "$password" "$(frame)")"
# The tip sits low in the field so the sign stays below the user-name field, out of the shot.
IFS=, read -r px py _ ph <<< "$password"
shot 5-password "$sheet" "$top" --text "Your Mac password here" --at "$((px + 8)),$((py + ph - 5))" --from left --size S --shape straight
undo_press || exit 1
echo "$HARMLESS is off again: $($AX value $HARMLESS)"
ls -la "$OUT"
