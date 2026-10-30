#!/bin/zsh
# README hero: a Hacker News front page on a real desktop (menu bar, Dock, a normal Chrome window
# with tabs and address bar) and nine arrows that make a point, no two alike. Run on the test Mac
# (Arthur) through scripts/arthur-gui.sh, never on a desk in use.
# - The page is the front page of 2014-06-10: every visible headline is tech, nothing political,
#   criminal or sad, and it fits "already argued in 2014".
# - Chrome gets a fresh temporary profile: no account, bookmarks or history. Other apps are hidden.
# - The whole main display is the shot, so nobody has to wonder whether it is real.
# Usage: scripts/hn-scene.sh <out.png> [window x,y,w,h]
set -uo pipefail
OUT="$1"
read WX WY WW WH <<< "${${2:-520,170,1080,830}//,/ }"
BIN=.build/release/bigarrow
URL="https://news.ycombinator.com/front?day=2014-06-10"
WORK=$(mktemp -d)
CHROME_PID=""
WIDGETS_HIDDEN=$(defaults read com.apple.WindowManager StandardHideWidgets 2>/dev/null || echo 0)
cleanup() {
  $BIN stop --all > /dev/null 2>&1
  [ -n "$CHROME_PID" ] && kill "$CHROME_PID" 2>/dev/null
  defaults write com.apple.WindowManager StandardHideWidgets -int "$WIDGETS_HIDDEN"
}
trap cleanup EXIT
# Desktop widgets (calendar, weather, photos) are not part of the scene.
defaults write com.apple.WindowManager StandardHideWidgets -bool true

open -na "Google Chrome" --args --user-data-dir="$WORK/chrome" --force-renderer-accessibility --new-window \
  --no-first-run --no-default-browser-check --disable-search-engine-choice-screen --hide-crash-restore-bubble \
  "$URL"
sleep 5
CHROME_PID=$(pgrep -f "MacOS/Google Chrome --user-data-dir=$WORK/chrome" | head -1)
[ -n "$CHROME_PID" ] || { echo "Chrome did not start" >&2; exit 1; }
for _ in {1..30}; do
  [ "$(osascript -e "tell application \"System Events\" to count windows of (first process whose unix id is $CHROME_PID)")" -gt 0 ] && break
  sleep 0.5
done
# Another Chrome may be running: this one is addressed by its pid.
osascript -e "tell application \"System Events\" to set visible of every process whose visible is true and unix id is not $CHROME_PID to false"
osascript > /dev/null <<AS
tell application "System Events" to tell (first process whose unix id is $CHROME_PID)
  set frontmost to true
  set position of window 1 to {$WX, $WY}
  set size of window 1 to {$WW, $WH}
  repeat 2 times
    click menu item "Zoom In" of menu "View" of menu bar 1
    delay 0.4
  end repeat
end tell
AS
sleep 1.5

# Targets from Accessibility, in global top-left points. The headlines are printed for review.
$BIN elements --app "Google Chrome" --json > "$WORK/ax.json" || exit 1
TARGETS=$(python3 - "$WORK/ax.json" <<'PY'
import json, re, sys
# Accessibility reports most page elements twice; keep one per role, label and frame.
nodes = list({(n["role"], n.get("title"), str(n["frame"])): n for n in json.load(open(sys.argv[1])) if n.get("frame")}.values())
links = [n for n in nodes if n["role"] == "AXLink"]
label = lambda n: (n.get("title") or n.get("label") or "").replace("\xa0", " ")
frame = lambda n: [v for pair in n["frame"] for v in pair]
link = lambda text: next(n for n in links if label(n) == text)
logo = next(n for n in links if label(n).startswith("To get missing image"))
comments = next(n for n in links if re.fullmatch(r"\d+ comments", label(n)))
title = link("Netflix responds to Verizon")
# The vote arrows sit in the narrow cells left of each headline; the 12th is row 12 (or the last one on screen).
votes = sorted((n for n in nodes if n["role"] == "AXCell" and title["frame"][0][0] - 45 < n["frame"][0][0] < title["frame"][0][0]
                and n["frame"][1][0] < 40), key=lambda n: n["frame"][0][1])
x, y, w, h = frame(logo); print(f"logo={x + 2:.0f},{y + h / 2:.0f}")
x, y, w, h = frame(link("past")); print(f"past={x + w / 2:.0f},{y + 2:.0f}")
x, y, w, h = frame(link("submit")); print(f"submit={x - 4:.0f},{y - 2:.0f},{w + 8:.0f},{h + 4:.0f}")
x, y, w, h = frame(comments); print(f"comments={x + w - 3:.0f},{y + h / 2:.0f}")
x, y, w, h = frame(votes[min(11, len(votes) - 1)]); print(f"vote={x + 7:.0f},{y + 11:.0f}")
# Headlines: these arrows land just right of the title, before the grey domain.
x, y, w, h = frame(link("Tell HN: The site was offline. What changed?")); print(f"tellhn={x + w + 4:.0f},{y + h / 2:.0f}")
x, y, w, h = frame(link("statwing.com")); print(f"survey={x + w + 6:.0f},{y + h / 2:.0f}")
x, y, w, h = frame(link("Firefox 30.0")); print(f"firefox={x - 6:.0f},{y - 4:.0f},{w + 12:.0f},{h + 8:.0f}")
x, y, w, h = frame(link("zef.me")); print(f"zfs={x + w + 6:.0f},{y + h / 2:.0f}")
x, y, w, h = frame(title)
for n in links:
    if abs(n["frame"][0][0] - x) <= 2 and n["frame"][1][1] >= 30:
        print(f"# headline: {label(n)}", file=sys.stderr)
PY
) || exit 1
typeset -A AT
for line in ${(f)TARGETS}; do AT[${line%%=*}]=${line#*=}; done

# Nine arrows from every side, every shape and style, each its own colour. Every point arrow must
# land exactly where it was sent: the script compares the target each one reports with the request.
: > "$WORK/arrows.json"
point() {
  local name="$1"; shift
  $BIN start "$@" --no-animation --no-raise --json >> "$WORK/arrows.json" || exit 1
  echo "drawn: $name"
}
point login --element login --role link --app "Google Chrome" --style ring --text "Not a lurker? Log in." \
  --color green --shape zigzag --from top --size S
point past --at "$AT[past]" --text "Already argued in 2014" --color teal --from top --size S
point logo --at "$AT[logo]" --text "Same since 2007" --color orange --corners sharp \
  --border white-black --shape straight --from left --size S
point comments --at "$AT[comments]" --text "The article is in here" --color purple --shape straight --from right --size S
point tellhn --at "$AT[tellhn]" --text "Nothing. Nothing changed." --color white --text-color "#5B2EFF" \
  --border black --shape spiral --from right --size S
point survey --at "$AT[survey]" --text "20,000 devs, 40,000 opinions" --color "#FF2D95" --close-button \
  --shape zigzag --from right --size S
point firefox --rect "$AT[firefox]" --style box --text "Remember me?" --color blue --from left --size S
point vote --at "$AT[vote]" --text "Finally, a bigger arrow" --color red --shape straight --from left --size S
point zfs --at "$AT[zfs]" --text "12 years later: still no consensus" --color black --border-color "#FF6600" \
  --corners sharp --from right --size S
python3 - "$WORK/arrows.json" "$AT[past]" "$AT[logo]" "$AT[comments]" "$AT[tellhn]" "$AT[survey]" "$AT[vote]" "$AT[zfs]" <<'PY' || { echo "an arrow missed its target" >&2; exit 1; }
import json, sys
arrows = [json.loads(line) for line in open(sys.argv[1])]
points = [arrows[i] for i in (1, 2, 3, 4, 5, 7, 8)]
for arrow, wanted in zip(points, sys.argv[2:]):
    x, y = (float(v) for v in wanted.split(","))
    target = arrow["target"]
    assert abs(target["x"] - x) <= 1 and abs(target["y"] - y) <= 1, (target, wanted)
assert arrows[0]["target"]["source"] == "element", arrows[0]["target"]
PY
sleep 2

# The whole main display: menu bar, Dock, Chrome and every sign.
screencapture -x "$WORK/shot.png" || exit 1
python3 - "$WORK/shot.png" "$OUT" <<'PY'
import sys
from PIL import Image
image = Image.open(sys.argv[1]).convert("RGB")
if image.width > 2400:  # a Retina display: README size
    image = image.resize((image.width // 2, image.height // 2), Image.LANCZOS)
image.quantize(256, method=Image.Quantize.MEDIANCUT, kmeans=2).save(sys.argv[2], optimize=True)
PY
echo "wrote $OUT"
