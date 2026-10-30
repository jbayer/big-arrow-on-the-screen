---
name: big-arrow
description: "Point at something on the human's macOS screen with a big arrow and a sign (\"Franz, click HERE\"), and hand over values, secrets and questions on a floating cue card, using the bigarrow CLI. Use whenever the human has to look at, click, type into or choose a specific spot, button, field, window, tab or menu: show me where, point to it, which button, where do I click, zeig mir wo, guide me through this UI, the human must approve or sign something, or you need the human's hand and they may not be looking at the terminal; also to hand over credentials, a password, token, 2FA code, IBAN or command to paste, or to ask the human a question or a choice while they are away from the terminal. Mandatory when it is time-critical: a code that expires, a login or payment page that times out, a build waiting on the human."
license: MIT
allowed-tools: Bash(bigarrow:*)
metadata:
  short-description: "Point at the screen with a big arrow and a sign"
---

# big-arrow

`bigarrow` draws a click-through arrow with a sign, needs no permission and never takes the
focus. Point at the thing itself, a line in the terminal is easy to miss.

Needs bigarrow 0.5.1 or newer. If `bigarrow --version` prints an older one, run
`brew upgrade franzenzenhofer/tap/bigarrow` first: an old binary has no `card` and prints
`{{value}}` as plain text.

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
bigarrow start --element "Ghostty" --app "System Settings" --text "Franz, switch this on: Ghostty may record your screen" --say
# watch for the result (page changed, job continued, file appeared), then:
bigarrow stop
```

## Rules

- Open the exact pane or URL yourself, then point at the one control left for the human. Never
  walk them through menus. The human clicks; you point.
- The sign is one full sentence naming the action ("Franz, click Save", never "here"). When the
  click approves, grants, pays, signs, sends or deletes, add what happens: "Franz, click Pay:
  49 EUR to Hetzner". The human decides; the facts go on the sign, not only in the terminal.
- `--say` when the human may not be looking. Time-critical (code expires, page times out, job
  waits): `--color red --say` and say by when: "Franz, enter the 2FA code now, it expires in 60 s".
- Something to paste (a command you may not run, a URL, a code): put it on the sign as
  `{{value}}`. The human sees the value on a copy button (no braces); one click copies all of it
  and the arrow stays. Point at where it goes: "Franz, copy {{sudo xcodebuild -license accept}}
  and paste it here", then check that it was pasted.
- One arrow per step; `bigarrow stop` the moment the step is done. Arrows also end alone: after
  300 s, when your session exits, when the human answers (hook below).
- A click on the sign or shaft, except a copy button, removes the arrow (target clicks pass
  through). A removed arrow was seen: check the result, do not redraw. Skip `--close-button`
  unless asked.

## Cards: values, secrets, answers

One value to paste: a `{{value}}` chip on the sign. Two or more values, any secret, or a question:
a cue card, a floating window with copy buttons that never takes the focus.

```bash
bigarrow card --title "Franz, log in to Hetzner" --app "Google Chrome" --field "User=franz@example.com" \
  --secret "Password=keychain:hetzner/franz" --link https://console.hetzner.cloud --button "done=I'm in"
bigarrow wait          # blocks until an answer: {"result":"button","value":"done","copied":["User","Password"],...}
```

- Secrets never go on the command line (`ps` shows it to everyone): `--secret` takes a source,
  `pass:`, `keychain:<service>/<account>`, `op:`, `env:`, `file:`, or put the value in a JSON card
  on stdin. They show as dots, copy as concealed and leave the clipboard after 30 s.
- `--ask "Question?"` (typed reply), `--choice id=Label` (2 to 6), `--button id=Label`. `wait`
  exits 0 for an answer, 1 when the human closed the card without one: then ask in the terminal.
- A card with questions closes itself once every question is answered (`--keep` keeps it until
  the X); the reply's `answers` has them all. A card with only values stays until the human's X.
  It survives your session and the prompt hook: close it yourself when it is no longer needed,
  `bigarrow stop --pid <pid>` or `bigarrow stop --cards`.
- A row can point: in a JSON card, `"point": {"element": "Password"}` aims the arrow at where that
  value goes, and it moves on when the human copies the next one. `start ... --card card.json`
  shows an arrow and a card together. Row types and JSON: [reference.md](reference.md#cards).

## Targets

| You know | Use |
|---|---|
| A label in a native or Electron app | `--element "Allow" --app "System Settings"` |
| An app or one of its windows | `--window "Safari"` / `--window "Safari:Inbox"` |
| A spot inside a Chrome tab | `--rect x,y,w,h --app "Google Chrome:<tab title>"` |
| A spot in a screenshot | `--at X,Y --app "<App>"` |

Always pass `--app` (or `--window`) for a target inside an app: it is raised first and the arrow
hides while another app covers it. `App:title` matches a window title, else a tab. Coordinates
are global top-left points. Inside a Chrome page `--element` needs Chrome started with
`--force-renderer-accessibility`; otherwise convert `getBoundingClientRect()` to `--rect`
([reference.md](reference.md)). Unsure? `bigarrow elements --app X --match "allow"` or `--dry-run`.

## Errors

Exit 2 bad input, 3 target not found (the message lists what exists), 4 permission missing: run
`bigarrow doctor`. Accessibility (`--element`, `App:title`, `--until-click`) and Screen Recording
(`--window App:title`) belong to the app running your shell (Terminal, Ghostty, VS Code), never
to bigarrow. Open the pane the error names (macOS 27: Accessibility is "Device Control and Data
Access") and point at that app's switch.

More (pane ids, look and timing flags): [reference.md](reference.md).

## Setup once

`~/.claude/settings.json`: `"hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bigarrow stop --hook"}]}]}`
