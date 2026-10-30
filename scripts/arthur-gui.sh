#!/bin/bash
# Runs a command on the test Mac (Arthur Mac) inside a Ghostty window, so it inherits Ghostty's
# Accessibility, PostEvent and Screen Recording permissions, waits for it, prints its output and
# exits with its code. Disruptive tests (drawing, clicks, raising apps, speech, virtual
# displays) run there, never on the Mac somebody is working on.
# Usage: scripts/arthur-gui.sh '<command run in ~/dev/big-arrow-on-the-screen>' [timeout-seconds]
set -euo pipefail
HOST="${ARTHUR_HOST:-arthur-mac}"
COMMAND="$1"
TIMEOUT="${2:-600}"
ID="bigarrow-$(date +%s)-$$"
# `open -na` starts a separate Ghostty instance per run, and its window outlives the command, so
# every run used to leave one Ghostty app behind. Quit this run's instance (and a hung command on
# timeout) whatever way the script ends. "[c]ommand" keeps pkill off the remote shell's own argv.
cleanup() {
  ssh "$HOST" "pkill -f '[c]ommand=/tmp/$ID/run.sh'; sleep 2; pkill -9 -f '[c]ommand=/tmp/$ID/run.sh'; rm -rf /tmp/$ID" || true
}
trap cleanup EXIT
ssh "$HOST" "mkdir -p /tmp/$ID && cat > /tmp/$ID/run.sh" <<SCRIPT
#!/bin/zsh -l
cd ~/dev/big-arrow-on-the-screen
(
$COMMAND
) > /tmp/$ID/out.log 2>&1
echo \$? > /tmp/$ID/exit
SCRIPT
ssh "$HOST" "chmod +x /tmp/$ID/run.sh && open -na Ghostty.app --args --quit-after-last-window-closed=true --command=/tmp/$ID/run.sh"
for _ in $(seq "$TIMEOUT"); do
  if ssh "$HOST" "test -f /tmp/$ID/exit"; then
    ssh "$HOST" "cat /tmp/$ID/out.log"
    exit "$(ssh "$HOST" "cat /tmp/$ID/exit")"
  fi
  sleep 1
done
echo "arthur-gui: timed out after $TIMEOUT s; partial output:" >&2
ssh "$HOST" "cat /tmp/$ID/out.log" >&2
exit 124
