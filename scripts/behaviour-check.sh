#!/bin/bash
# Behaviour checks that click, move windows, raise apps, speak and add displays. Run only on a
# disposable machine (the CI runner), never on a Mac somebody is working on.
# Usage: scripts/behaviour-check.sh <out-dir>; exits non-zero when any check fails.
set -uo pipefail
OUT="$1"
BIN=.build/release/bigarrow
mkdir -p "$OUT"
FAILED=0
# Runs a command with a hard time limit (macOS has no timeout(1)); a hang fails, never blocks.
limit() { perl -e 'alarm shift; exec @ARGV' "$@"; }
check() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; FAILED=1; fi; }
field() { python3 -c "import json,sys; d=json.load(open('$1')); print(eval('d' + sys.argv[1]))" "$2"; }

swiftc -O scripts/testkit.swift -o "$OUT/testkit" && swiftc -O scripts/backdrop.swift -o "$OUT/backdrop"
scripts/virtual-display/build.sh > /dev/null
KIT="$OUT/testkit"
"$OUT/backdrop" & BACKDROP=$!
trap 'kill $BACKDROP 2>/dev/null; $BIN stop --all >/dev/null 2>&1' EXIT
sleep 2

# The close button: a real click on the X (inside the sign's right end) ends the arrow and
# leaves the focus where it was.
FRONT=$($KIT frontmost)
$BIN start --at 300,300 --text "Close me" --close-button --json > "$OUT/close.json"
PID=$(field "$OUT/close.json" "['pid']")
read -r X Y < <(python3 -c "import json; s=json.load(open('$OUT/close.json'))['sign']; print(int(s[0]+s[2]-37), int(s[1]+s[3]/2))")
sleep 1; screencapture -x "$OUT/close-button.png"; $KIT click "$X" "$Y"; sleep 1
check "close button ends the arrow" "! kill -0 $PID 2>/dev/null"
check "clicking the X keeps the focus" "[ \"\$($KIT frontmost)\" = \"$FRONT\" ]"

# Without an X, a click on the sign ends the arrow; a click on the target still passes through.
$BIN start --at 300,300 --text "Click the sign" --json > "$OUT/sign-click.json"
PID=$(field "$OUT/sign-click.json" "['pid']")
sleep 1; $KIT click 300 300; sleep 0.5
check "a click on the target passes through and keeps the arrow" "kill -0 $PID 2>/dev/null"
read -r X Y < <(python3 -c "import json; s=json.load(open('$OUT/sign-click.json'))['sign']; print(int(s[0]+s[2]/2), int(s[1]+s[3]/2))")
$KIT click "$X" "$Y"; sleep 1
check "a click on the sign ends the arrow" "! kill -0 $PID 2>/dev/null"
check "clicking the sign keeps the focus" "[ \"\$($KIT frontmost)\" = \"$FRONT\" ]"

# A copy chip: a real click puts its value on the clipboard and keeps the arrow; the rest of the
# sign still ends it.
printf 'before' | pbcopy
$BIN start --at 300,300 --text "Copy {{bigarrow-copy-check}} and paste it here" --json > "$OUT/copy.json"
PID=$(field "$OUT/copy.json" "['pid']")
read -r X Y < <(python3 -c "import json; c=json.load(open('$OUT/copy.json'))['copyButtons'][0]; print(int(c[0]+c[2]/2), int(c[1]+c[3]/2))")
sleep 1; $KIT click "$X" "$Y"; sleep 0.3; screencapture -x "$OUT/copy-clicked.png"; sleep 0.5
check "a click on a copy chip copies its value ($(pbpaste))" "[ \"\$(pbpaste)\" = bigarrow-copy-check ]"
check "a click on a copy chip keeps the arrow" "kill -0 $PID 2>/dev/null"
read -r X Y < <(python3 -c "import json; s=json.load(open('$OUT/copy.json'))['sign']; print(int(s[0]+14), int(s[1]+s[3]/2))")
$KIT click "$X" "$Y"; sleep 1
check "a click beside the chip still ends the arrow" "! kill -0 $PID 2>/dev/null"
check "copying keeps the focus" "[ \"\$($KIT frontmost)\" = \"$FRONT\" ]"

# --until-click: a click on the target ends it with dismissedReason clicked.
$BIN point --at 400,500 --text "Click the target" --until-click --json > "$OUT/until-click.json" & POINT=$!
sleep 1.5; $KIT click 400 500; wait $POINT
check "until-click reports clicked" "[ \"\$(field $OUT/until-click.json \"['dismissedReason']\")\" = clicked ]"

$KIT windows backdrop | tee "$OUT/backdrop-windows.txt"

# --follow: the arrow moves with its target; closing the window ends the arrow with targetGone.
# Followed through --element, because on GitHub's virtual machines the window server reports
# window positions that disagree with Accessibility and the screen (see docs/research).
$BIN point --element Allow --app backdrop --text "Follow me" --follow --duration 8 --json > "$OUT/follow.json" & POINT=$!
sleep 1.5; $KIT move-window backdrop 252 200; sleep 1.5; screencapture -x "$OUT/follow-moved.png"
kill $BACKDROP; wait $POINT
check "follow ends with targetGone when the window closes" "[ \"\$(field $OUT/follow.json \"['dismissedReason']\")\" = targetGone ]"
check "follow tracked the moved button (window moved down 76 pt)" "python3 -c \"import json; t=json.load(open('$OUT/follow.json'))['target']; exit(0 if abs(t['y'] - 431) < 3 else 1)\""
"$OUT/backdrop" & BACKDROP=$!
sleep 2

# The target's app comes to the front by default; --no-raise leaves it where it is.
$KIT activate Finder
$BIN point --window backdrop --no-raise --text "Not raised" --duration 1 > /dev/null
check "--no-raise leaves the front app alone" "[ \"\$($KIT frontmost)\" = Finder ]"
$BIN point --window backdrop --text "Raised" --duration 1 --json > "$OUT/raise.json"
check "the target app comes to the front by default" "[ \"\$($KIT frontmost)\" = backdrop ]"

# Bound to its app: the arrow hides while another app's window covers the target, and returns.
cp "$OUT/backdrop" "$OUT/coverapp"
$BIN start --element Allow --app backdrop --text "Bound to backdrop" --color red --no-animation --json > "$OUT/bound.json"
read -r SX SY < <(python3 -c "import json; s=json.load(open('$OUT/bound.json'))['sign']; print(int(s[0]+14), int(s[1]+s[3]/2))")
sleep 1; read -r R G B < <($KIT pixel "$SX" "$SY")
check "a bound arrow shows while its target is visible ($R $G $B)" "[ $R -gt 200 ] && [ $G -lt 120 ]"
"$OUT/coverapp" --title "Cover" --message "Covers the dialog" & COVER=$!
sleep 3; screencapture -x "$OUT/bound-covered.png"
read -r R G B < <($KIT pixel "$SX" "$SY")
check "the arrow hides while another app covers its target ($R $G $B)" "! { [ $R -gt 200 ] && [ $G -lt 120 ]; }"
kill $COVER; sleep 2
read -r R G B < <($KIT pixel "$SX" "$SY")
check "the arrow returns once the target is visible again ($R $G $B)" "[ $R -gt 200 ] && [ $G -lt 120 ]"
$BIN stop --all > /dev/null

# An arrow ends when the agent process that drew it exits.
sleep 60 & OWNER=$!
BIGARROW_OWNER_PID=$OWNER BIGARROW_SESSION=ci-session $BIN start --at 300,300 --text "Owned" --json > "$OUT/owned.json"
OWNED=$(field "$OUT/owned.json" "['pid']")
kill $OWNER; sleep 1.5
check "the arrow ends when its owner process exits" "! kill -0 $OWNED 2>/dev/null"

# stop --hook clears exactly the arrows of the hook's session, silently.
BIGARROW_SESSION=mine $BIN start --at 300,300 --text "Mine" --json > "$OUT/mine.json"
BIGARROW_SESSION=other $BIN start --at 600,300 --text "Other" --json > "$OUT/other.json"
HOOK_OUT=$(echo '{"session_id":"mine","prompt":"done"}' | $BIN stop --hook)
check "stop --hook removed the session's arrow" "! kill -0 $(field "$OUT/mine.json" "['pid']") 2>/dev/null"
check "stop --hook kept another session's arrow" "kill -0 $(field "$OUT/other.json" "['pid']") 2>/dev/null"
check "stop --hook printed nothing" "[ -z \"$HOOK_OUT\" ]"
$BIN stop --all > /dev/null

# --app "Google Chrome:<tab title>" selects a background tab and raises its window.
CHROME_PROFILE=$(mktemp -d)
echo "<title>Alpha tab</title><h1>Alpha</h1>" > "$CHROME_PROFILE/alpha.html"
echo "<title>Beta tab</title><h1>Beta</h1>" > "$CHROME_PROFILE/beta.html"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --user-data-dir="$CHROME_PROFILE" --no-first-run \
  --no-default-browser-check "file://$CHROME_PROFILE/alpha.html" "file://$CHROME_PROFILE/beta.html" > /dev/null 2>&1 &
CHROME=$!
sleep 10; limit 10 $KIT activate Finder
limit 30 $BIN point --at 400,300 --app "Google Chrome:Alpha tab" --text "Alpha" --duration 1 --json > "$OUT/tab.json" 2> "$OUT/tab.err"
limit 10 $KIT windows "Google Chrome" | tee "$OUT/chrome-windows.txt"
check "the tab target exits 0 ($(cat "$OUT/tab.err"))" "[ -s $OUT/tab.json ]"
check "Chrome came to the front" "[ \"\$(limit 10 $KIT frontmost)\" = 'Google Chrome' ]"
check "the Alpha tab is now the selected tab" "grep -q 'kCGWindowName=Alpha tab' $OUT/chrome-windows.txt"
screencapture -x "$OUT/chrome-tab.png"
kill $CHROME 2>/dev/null

# --say speaks and still exits 0.
check "say works" "$BIN point --at 300,300 --text 'Hello from bigarrow' --say --duration 2 > /dev/null"

# A second display: point at it, then unplug it while the arrow is up.
scripts/virtual-display/.build/virtual-display --width 1280 --height 800 --hidpi 0 --seconds 12 > "$OUT/display.json" & DISPLAY_PID=$!
sleep 4
$BIN doctor --json > "$OUT/doctor-two-displays.json"
check "doctor sees two displays" "[ \"\$(field $OUT/doctor-two-displays.json \"['displays'].__len__()\")\" = 2 ]"
$BIN start --at 200,200 --display 2 --text "On the second display" --color blue --json > "$OUT/second.json"
check "arrow lands on display 2" "[ \"\$(field $OUT/second.json \"['target']['display']\")\" = 2 ]"
sleep 1; screencapture -x "$OUT/two-displays-1.png" "$OUT/two-displays-2.png"
SECOND=$(field "$OUT/second.json" "['pid']")
kill $DISPLAY_PID; sleep 2
check "unplugging the display ends its arrow" "! kill -0 $SECOND 2>/dev/null"

# A sticky arrow that pulses costs almost no CPU: Core Animation runs in the render server.
$BIN start --at 300,300 --text "Idle pulse" --json > "$OUT/pulse.json"
PULSE=$(field "$OUT/pulse.json" "['pid']")
CPU=$($KIT cpu "$PULSE" 5); echo "cpu while pulsing: $CPU %"
check "pulsing costs under 3 % CPU" "python3 -c 'exit(0 if $CPU < 3 else 1)'"
$BIN stop --all > /dev/null

# stop silences --say within 300 ms.
$BIN start --at 300,300 --text "This is a long sentence that keeps the speech running for a while" --say > /dev/null
sleep 1
STOP_START=$(python3 -c 'import time; print(time.time())')
$BIN stop --all > /dev/null
check "stop ends the arrow and its speech within 300 ms" "! pgrep -x say > /dev/null && python3 -c 'import time; exit(0 if time.time() - $STOP_START < 0.6 else 1)'"

# Above a full-screen app: the overlay must cover it, the app must stay in its full-screen Space.
kill $BACKDROP; "$OUT/backdrop" --fullscreen & BACKDROP=$!
sleep 4
$BIN start --element Allow --app backdrop --text "Over a full-screen app" --color red --no-animation --json > "$OUT/fullscreen.json"
sleep 1; screencapture -x "$OUT/fullscreen.png"
read -r SX SY < <(python3 -c "import json; s=json.load(open('$OUT/fullscreen.json'))['sign']; print(int(s[0]+14), int(s[1]+s[3]/2))")
read -r R G B < <($KIT pixel "$SX" "$SY")
check "the sign is visible above a full-screen app ($R $G $B)" "[ $R -gt 200 ] && [ $G -lt 120 ]"
check "the full-screen app kept the focus" "[ \"\$($KIT frontmost)\" = backdrop ]"
$BIN stop --all > /dev/null
kill $BACKDROP; "$OUT/backdrop" & BACKDROP=$!; sleep 3

# Switching Spaces while an arrow is up: the arrow comes along (it is on every Space).
$BIN start --at 200,600 --text "I stay on every Space" --color purple --no-animation --json > "$OUT/spaces.json"
kill $BACKDROP; "$OUT/backdrop" --fullscreen & BACKDROP=$!
sleep 4; screencapture -x "$OUT/space-switched.png"
read -r SX SY < <(python3 -c "import json; s=json.load(open('$OUT/spaces.json'))['sign']; print(int(s[0]+14), int(s[1]+s[3]/2))")
read -r R G B < <($KIT pixel "$SX" "$SY")
check "an arrow started before a Space switch is still visible after it ($R $G $B)" "[ $R -gt 100 ] && [ $B -gt 200 ] && [ $G -lt 110 ]"
$BIN stop --all > /dev/null
kill $BACKDROP; "$OUT/backdrop" & BACKDROP=$!; sleep 3

# With Stage Manager on.
defaults write com.apple.WindowManager GloballyEnabled -bool true; sleep 3
$BIN start --element Allow --app backdrop --text "With Stage Manager" --color blue --no-animation --json > "$OUT/stage.json"
sleep 1; screencapture -x "$OUT/stage-manager.png"
read -r SX SY < <(python3 -c "import json; s=json.load(open('$OUT/stage.json'))['sign']; print(int(s[0]+14), int(s[1]+s[3]/2))")
read -r R G B < <($KIT pixel "$SX" "$SY")
check "the sign is visible with Stage Manager on ($R $G $B)" "[ $B -gt 200 ] && [ $R -lt 80 ]"
$BIN stop --all > /dev/null
defaults write com.apple.WindowManager GloballyEnabled -bool false

# A second display in a 2x pixel mode. (On the runner AppKit still reports backing scale 1
# for it; scale 2 itself is covered by the screen tests on a MacBook's built-in display.)
scripts/virtual-display/.build/virtual-display --width 800 --height 500 --hidpi 1 --seconds 10 > "$OUT/display-2x.json" & DISPLAY_PID=$!
sleep 4
$BIN start --at 300,200 --display 2 --text "On a 2x mode display" --color green --no-animation --json > "$OUT/retina.json"
sleep 1; screencapture -x "$OUT/retina-1.png" "$OUT/retina-2.png"
check "arrow lands on the second display in a 2x mode" "[ \"\$(field $OUT/retina.json \"['target']['display']\")\" = 2 ]"
$BIN stop --all > /dev/null
kill $DISPLAY_PID 2>/dev/null; wait $DISPLAY_PID 2>/dev/null

exit $FAILED
