#!/bin/bash
# Stages the README's "Funny cue cards": a real app (Finder, Chrome with a made-up local page, or
# the neutral backdrop dialog), an arrow and a cue card, one screenshot each, cropped around the
# window, the card and the arrow's sign. Run on the test Mac (Arthur), never on a desk in use.
# Other apps are hidden, the Dock and desktop widgets too (restored on exit); demo files live in
# a temporary folder and Chrome gets a fresh temporary profile, so nothing personal is on screen.
# Cards float below system alerts, so `backdrop --cover` cannot hide the desktop here: move any
# pending alert out of the scenes' way (x below 1440 stays free) before the run.
# The shot never goes above CLEAN_TOP (default 32 points: no menu bar).
# Usage: [CLEAN_TOP=32] scripts/card-scenes.sh <out-dir> [scene ...]
#   scenes: node-modules arrows lunch deploy coffee git (default: all)
set -uo pipefail
OUT="$1"; shift
SCENES="${*:-node-modules arrows lunch deploy coffee git}"
BIN=.build/release/bigarrow
CLEAN_TOP="${CLEAN_TOP:-32}"
# The top of every scene's window: room above and below for the signs.
Y=300
WORK=$(cd "$(mktemp -d /tmp/card-scenes.XXXXXX)" && pwd -P)
mkdir -p "$OUT"
swiftc -O scripts/testkit.swift -o "$WORK/testkit" || exit 1
swiftc -O scripts/backdrop.swift -o "$WORK/backdrop" || exit 1
KIT="$WORK/testkit"
SCREEN=$(osascript -e 'tell application "Finder" to get bounds of window of desktop' | awk -F', ' '{print $3 "," $4}')
DOCK_AUTOHIDE=$(defaults read com.apple.dock autohide 2>/dev/null || echo 0)
WIDGETS_HIDDEN=$(defaults read com.apple.WindowManager StandardHideWidgets 2>/dev/null || echo 0)
CHROME_PID=""; BACKDROP=""; FINDER_FOLDER=""
close_chrome() { [ -n "$CHROME_PID" ] && kill "$CHROME_PID" 2>/dev/null; CHROME_PID=""; }
close_backdrop() { [ -n "$BACKDROP" ] && kill "$BACKDROP" 2>/dev/null; BACKDROP=""; }
close_finder() {
  [ -n "$FINDER_FOLDER" ] && osascript - "$(basename "$FINDER_FOLDER")" > /dev/null 2>&1 <<'AS'
on run {wanted}
  tell application "System Events" to tell process "Finder"
    repeat with w in (every window whose name is wanted)
      click (first button of w whose subrole is "AXCloseButton")
    end repeat
  end tell
end run
AS
  FINDER_FOLDER=""
}
end_scene() {
  $BIN stop --all > /dev/null 2>&1; $BIN stop --cards > /dev/null 2>&1
  close_chrome; close_backdrop; close_finder
  : > "$WORK/rects"; CARD_PIDS=""
}
cleanup() {
  end_scene
  defaults write com.apple.dock autohide -int "$DOCK_AUTOHIDE"; killall Dock
  defaults write com.apple.WindowManager StandardHideWidgets -int "$WIDGETS_HIDDEN"
}
trap cleanup EXIT
defaults write com.apple.dock autohide -bool true; killall Dock
defaults write com.apple.WindowManager StandardHideWidgets -bool true
killall NotificationCenter 2>/dev/null
: > "$WORK/rects"; CARD_PIDS=""

hide_others_than_pid() {
  osascript -e "tell application \"System Events\" to set visible of every process whose visible is true and unix id is not $1 to false"
}
# keep <x,y,w,h>: a rect the shot must contain.
keep() { echo "$1" >> "$WORK/rects"; }
# card_of <pid>: the frame of that process's cue card (the panel on window layer 3).
card_of() {
  "$KIT" windows "$1" | python3 -c 'import re, sys
for line in sys.stdin:
    if "kCGWindowLayer=3 " in line:
        v = dict(re.findall(r"(\w+) = (-?[\d.]+);", line))
        print(",".join(v[k] for k in ("X", "Y", "Width", "Height")))
        break'
}
# arrow <command...>: one bigarrow start with --json; keeps its sign (and its card, if it has one).
# With --card the JSON describes the card, so the sign comes from the same command as a dry run.
arrow() {
  local out plain=() arg skip=""
  out=$("$@" --no-animation --json) || { echo "arrow failed: $*" >&2; exit 1; }
  ARROW_PID=$(echo "$out" | python3 -c 'import json, sys; print(json.load(sys.stdin)["pid"])')
  for arg in "$@"; do
    if [ -n "$skip" ]; then skip=""; elif [ "$arg" = --card ]; then skip=1; CARD_PIDS="$CARD_PIDS $ARROW_PID"; else plain+=("$arg"); fi
  done
  [ "${#plain[@]}" -lt "$#" ] && out=$("${plain[@]}" --no-raise --no-animation --dry-run --json)
  echo "$out" | python3 -c 'import json, sys; print(",".join(str(v) for v in json.load(sys.stdin)["sign"]))' >> "$WORK/rects"
}
# card <args...>: bigarrow card; sets CARD_JSON (its controls). Its frame is read at the shot,
# after any "Sent" banner has grown it.
card() {
  CARD_JSON=$($BIN card "$@") || { echo "card failed: $*" >&2; exit 1; }
  CARD_PIDS="$CARD_PIDS $(echo "$CARD_JSON" | python3 -c 'import json, sys; print(json.load(sys.stdin)["pid"])')"
}
# control <label>: the middle of the card control with that name, "x y".
control() {
  echo "$CARD_JSON" | python3 -c 'import json, sys
r = next(c["rect"] for c in json.load(sys.stdin)["controls"] if c["name"] == sys.argv[1])
print(round(r[0] + r[2] / 2), round(r[1] + r[3] / 2))' "$1"
}
# click_element <app> <label>: a real click in the middle of the first element with that label.
click_element() {
  local at
  at=$($BIN elements --app "$1" --match "$2" --json | python3 -c 'import json, sys
f = json.load(sys.stdin)[0]["frame"]
print(round(f[0][0] + f[1][0] / 2), round(f[0][1] + f[1][1] / 2))')
  $KIT click $at
}
# shoot <name> [seconds]: captures every kept rect, 32 pt around them, never above CLEAN_TOP.
shoot() {
  sleep "${2:-1.2}"
  local region pid
  for pid in $CARD_PIDS; do keep "$(card_of "$pid")"; done
  region=$(python3 - "$WORK/rects" "$SCREEN" "$CLEAN_TOP" <<'PY'
import sys
rects = [[float(v) for v in line.split(",")] for line in open(sys.argv[1]) if line.strip()]
screen_w, screen_h = (float(v) for v in sys.argv[2].split(","))
pad = 32
left = max(min(r[0] for r in rects) - pad, 0)
top = max(min(r[1] for r in rects) - pad, float(sys.argv[3]))
right = min(max(r[0] + r[2] for r in rects) + pad, screen_w)
bottom = min(max(r[1] + r[3] for r in rects) + pad, screen_h)
print(f"{left:.0f},{top:.0f},{right - left:.0f},{bottom - top:.0f}")
PY
)
  screencapture -x -R "$region" "$OUT/$1.png"
  echo "$OUT/$1.png" >> "$WORK/shots.txt"
  echo "$1: $region"
  end_scene
}
# page <file> <title> <x> <y> <w> <h> <html body>: a made-up local page in a fresh Chrome app window.
page() {
  local profile="$WORK/chrome-$1"
  cat > "$WORK/$1.html" <<HTML
<!doctype html><meta charset="utf-8"><title>$2</title>
<style>
  body { margin: 0; height: 100vh; display: grid; place-items: center; background: #f6f7f9;
         font: 18px -apple-system, sans-serif; color: #111; }
  main { background: #fff; padding: 28px 40px; border-radius: 16px; box-shadow: 0 6px 24px #0002; min-width: 380px; }
  h1 { font-size: 26px; margin: 0 0 6px; } p { margin: 0 0 16px; color: #555; }
  li { margin: 8px 0; } small { color: #888; font-size: 16px; }
  input { font: 600 30px ui-monospace, monospace; letter-spacing: 8px; width: 200px; padding: 8px 12px;
          border: 2px solid #ccc; border-radius: 10px; text-align: center; }
  button { font: 600 20px -apple-system, sans-serif; padding: 10px 22px; border-radius: 10px; border: 0;
           background: #6b4226; color: #fff; margin-left: 10px; }
</style>
<main>$7</main>
HTML
  open -na "Google Chrome" --args --user-data-dir="$profile" --no-first-run --no-default-browser-check \
    --disable-search-engine-choice-screen --hide-crash-restore-bubble --force-renderer-accessibility \
    --disable-features=MediaRouter --app="file://$WORK/$1.html"; sleep 5
  CHROME_PID=$(pgrep -f "MacOS/Google Chrome --user-data-dir=$profile" | head -1)
  [ -n "$CHROME_PID" ] || { echo "$1: the temporary Chrome did not start" >&2; exit 1; }
  hide_others_than_pid "$CHROME_PID"
  osascript > /dev/null <<AS
tell application "System Events" to tell (first process whose unix id is $CHROME_PID)
  set position of window 1 to {$3, $4}
  set size of window 1 to {$5, $6}
end tell
AS
  keep "$3,$4,$5,$6"; sleep 1
}
# dialog <x> <y> <title> <message> <buttons>: the neutral backdrop dialog, top-left at x,y.
dialog() {
  "$WORK/backdrop" --x "$1" --y "$2" --title "$3" --message "$4" --buttons "$5" & BACKDROP=$!; disown "$BACKDROP"
  sleep 2.5
  hide_others_than_pid "$BACKDROP"
  keep "$1,$2,520,288"
}

scene_node-modules() {
  local folder="$WORK/my-app"
  mkdir -p "$folder/node_modules" "$folder/src"
  echo '{}' > "$folder/package.json"; echo "# my-app" > "$folder/README.md"
  FINDER_FOLDER="$folder"
  open "$folder"; sleep 2
  # Other Finder windows (somebody's Downloads, say) are minimized, never closed.
  osascript - my-app > /dev/null 2>&1 <<'AS'
on run {wanted}
  tell application "System Events" to tell process "Finder"
    repeat with i from (count windows) to 1 by -1
      try
        if name of window i is not wanted then set value of attribute "AXMinimized" of window i to true
      end try
    end repeat
  end tell
end run
AS
  osascript -e 'tell application "Finder" to set sidebar width of front window to 0' \
    -e 'tell application "Finder" to set current view of front window to icon view' \
    -e "tell application \"Finder\" to set bounds of front window to {160, $Y, 760, $((Y + 260))}" > /dev/null
  osascript -e 'tell application "System Events" to set visible of every process whose visible is true and name is not "Finder" to false'
  keep "160,$Y,600,260"; sleep 1
  cat > "$WORK/node-modules.json" <<'JSON'
{"title": "Franz, delete node_modules?", "app": "Finder:my-app", "color": "green", "rows": [
  {"type": "text", "value": "**3.4 GB**, 847,293 files. You have opened none of them."},
  {"type": "actions", "items": [{"id": "grieve", "label": "Let me grieve first"},
                                {"id": "delete", "label": "Yes, finally", "style": "primary"}]}]}
JSON
  arrow $BIN start --element node_modules --app Finder:my-app --text "847,293 files live here. Rent-free." \
    --from bottom-right --size S --color green --no-raise --card "$WORK/node-modules.json"
  shoot node-modules
}

# A choice, answered: a real click on the pick lights it up ("keep" holds the card for the shot).
scene_arrows() {
  dialog 160 $Y "Arrow budget" "Franz has used 40 of 40 arrows this week. The agent would like to point at more things." "Later,Ask Franz"
  card - <<'JSON'
{"title": "Franz, approve 3 more arrows?", "app": "backdrop", "color": "purple", "keep": true, "rows": [
  {"type": "choice", "items": [
    {"id": "three", "label": "Yes, 3 more", "detail": "The sensible option"},
    {"id": "twelve", "label": "Make it 12", "detail": "Go big or go home"},
    {"id": "bigger", "label": "One, but bigger", "detail": "--size L, obviously"}]}]}
JSON
  $KIT click $(control "One, but bigger")
  arrow $BIN start --element "Ask Franz" --app backdrop --text "Too late. He picked." --from bottom-left \
    --size S --color purple --no-raise
  shoot arrows
}

# An open question with a typed answer: a real click into the field, real typing.
scene_lunch() {
  page lunch "Canteen" 160 $Y 520 300 '<h1>Today at the canteen</h1><p>Orders close at 11:30</p>
<ul><li>Mystery casserole</li><li>Soup of the day (yesterday)</li><li>Salad, which is lettuce</li></ul>'
  card - <<'JSON'
{"title": "Franz, what do you want for lunch?", "app": "Google Chrome:Canteen", "color": "orange", "rows": [
  {"type": "input", "id": "lunch", "label": "Orders close at 11:30. The agent cannot taste, so you choose."}]}
JSON
  echo "$CARD_JSON" >&2
  $KIT click $(control "Orders close at 11:30. The agent cannot taste, so you choose.")
  sleep 0.5; $KIT type "Anything but the casserole"
  arrow $BIN start --element "Mystery casserole" --app "Google Chrome:Canteen" --text "Brave. Not recommended." \
    --from bottom-right --size S --color orange --no-raise
  shoot lunch
}

# A checklist, half done, and the arrow on the button it guards.
scene_deploy() {
  dialog 160 $Y "Deploy" "Deploy to production? It is Friday, 17:55." "Cancel,Deploy"
  card - <<'JSON'
{"title": "Franz, Friday deploy checklist", "app": "backdrop", "color": "blue", "rows": [
  {"type": "checklist", "id": "deploy", "items": [
    {"id": "tests", "label": "Tests are green"},
    {"id": "rollback", "label": "Rollback plan written"},
    {"id": "team", "label": "Team told"},
    {"id": "phone", "label": "Phone charged for the weekend"},
    {"id": "peace", "label": "Inner peace found"}]}]}
JSON
  echo "$CARD_JSON" >&2
  $KIT click $(control "Tick Tests are green"); sleep 0.3
  $KIT click $(control "Tick Rollback plan written"); sleep 0.3
  $KIT click $(control "Tick Team told")
  arrow $BIN start --element Deploy --role button --app backdrop --text "Only when all five are ticked" --from bottom-left \
    --size S --color blue --no-raise
  shoot deploy
}

# A row that points at where its value goes: the arrow comes from the card itself.
scene_coffee() {
  page coffee "Coffee machine" 640 $Y 520 260 '<h1>Coffee machine</h1><p>3rd floor, the good one</p>
<input aria-label="PIN" placeholder="PIN"><button>Brew</button>'
  card - <<'JSON'
{"title": "Franz, coffee is one PIN away", "app": "Google Chrome:Coffee machine", "color": "#8B5A2B", "rows": [
  {"type": "field", "label": "Machine PIN", "value": "4711",
   "point": {"element": "PIN", "app": "Google Chrome:Coffee machine", "text": "Paste the PIN here, then Brew"}},
  {"type": "field", "label": "Strength", "value": "Yes"},
  {"type": "text", "value": "Cups today: 4. The agent is not judging."}]}
JSON
  # The card draws this arrow itself; the same target as a dry run says where its sign is.
  $BIN point --element PIN --app "Google Chrome:Coffee machine" --text "Paste the PIN here, then Brew" \
    --dry-run --json | python3 -c 'import json, sys; print(",".join(str(v) for v in json.load(sys.stdin)["sign"]))' >> "$WORK/rects"
  shoot coffee 2
}

# Copy buttons, one of them just clicked.
scene_git() {
  page git "Search" 160 $Y 560 240 '<h1>Search</h1><p>how to undo the last git commit</p>
<small>You searched for this 52 times this year.</small>'
  card - <<'JSON'
{"title": "Franz, it's this one. Again.", "app": "Google Chrome:Search", "color": "teal", "rows": [
  {"type": "code", "value": "git reset --soft HEAD~1"},
  {"type": "field", "label": "Searched this year", "value": "52 times"},
  {"type": "text", "value": "Copy it. Frame it. Hang it above the desk."}]}
JSON
  echo "$CARD_JSON" >&2
  arrow $BIN start --element "how to undo the last git commit" --app "Google Chrome:Search" \
    --text "No need. The agent remembers." --from bottom-right --size S --color teal --no-raise
  $KIT click $(control "Copy code")
  shoot git 0.6
}

for scene in $SCENES; do "scene_$scene"; done
# README size: wider than 1400 px is scaled down, then 256 colours.
while read -r shot; do
  python3 - "$shot" <<'PY'
import sys
from PIL import Image
path = sys.argv[1]
image = Image.open(path).convert("RGB")
if image.width > 1400:
    image = image.resize((1400, round(image.height * 1400 / image.width)), Image.LANCZOS)
image.quantize(256, method=Image.Quantize.MEDIANCUT, kmeans=2).save(path, optimize=True)
PY
done < "$WORK/shots.txt"
ls -la "$OUT"
