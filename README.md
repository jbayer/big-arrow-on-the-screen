# Let your AI agents paint big arrows, boxes and text on your screen

**big-arrow-on-the-screen** (`bigarrow`) is a macOS command-line tool, plus a skill for Claude Code and Codex, that draws an arrow and a sign on top of every window. Clicks go through, your keyboard focus stays put, and the arrow removes itself. MIT licensed.

[![CI](https://github.com/franzenzenhofer/big-arrow-on-the-screen/actions/workflows/ci.yml/badge.svg)](https://github.com/franzenzenhofer/big-arrow-on-the-screen/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

![A real macOS desktop, Hacker News of 2014-06-10 in Chrome, nine bigarrow arrows in nine colours from every side: same since 2007, already argued in 2014, not a lurker? log in, the article is in here, remember me? (Firefox 30), nothing. nothing changed. (a spiral, going round in circles), 20,000 devs 40,000 opinions, finally a bigger arrow, 12 years later: still no consensus](docs/images/hero-hn.png)

[Real apps](#real-apps-real-use-cases) · [Copy & paste](#copy--paste) · [Cue cards](#cue-cards-values-secrets-answers) · [What is it for?](#what-is-this-actually-for) · [Install](#install) · [Commands](#the-three-commands-an-agent-needs) · [Looks](#looks) · [Creative arrows](#creative-arrows) · [Starred by](#starred-by) · [FAQ](#faq) · [How we know it works](#how-we-know-it-works) · [For agents](#for-agents-and-the-humans-who-configure-them) · [Plan](#plan-decisions-research) · [Prior art](#prior-art-and-thanks) · [License](#license)

> Your AI agent can refactor a monorepo, write a migration and explain monads, but when it needs you to click one button it prints *"please click Allow in the dialog"* into a terminal you are not looking at. `bigarrow` gives it a finger.

![bigarrow pointing at a dialog's Allow button](docs/images/demo.gif)

```bash
bigarrow point --element "Allow" --app "System Settings" --text "Franz, click Allow: Ghostty may control your Mac"
```

One transparent window above everything, on every display and every Space. Drawing needs **no macOS permission at all**. One Swift binary: no daemon, no menu-bar icon, no account, no telemetry, and, we checked twice, no AI inside. It is an arrow.

## Real apps, real use cases

Real apps on a real Mac (macOS 27), the real `bigarrow`, staged by `scripts/real-scenes.sh`.

### macOS Desktop & Dock: stop "click wallpaper to show desktop"

![An agent walks a human through the most complained-about Mac setting since 2023: one click on the wallpaper and every window flees; then 1. The apple. Yes, the fruit. 2. System Settings. Where settings go to hide. 3. Desktop & Dock. Not Wallpaper. Not Displays. This one. 4. Scroll. Further. It's always further. 5. 'Show desktop'. Nothing to do with Stage Manager. 6. 'Only in Stage Manager' means 'off'. Obviously. Then the wallpaper click: Nothing happens. Bliss.](docs/images/real/wallpaper.gif)

["The most annoying change in Mac update history"](https://www.imore.com/mac/macos/macos-sonoma-click-to-reveal-desktop-turn-off), fixed in six arrows ([MP4](docs/videos/wallpaper.mp4)).

### System Settings: grant a permission

![System Settings, Device Control and Data Access: a green arrow with a close button, Franz, switch this on: Terminal may control your Mac, and an orange zigzag ring on the plus button: Not in the list? Plus. Then find it.](docs/images/real/settings.png)

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
bigarrow start --element Terminal_Toggle --app "System Settings" \
  --text "Franz, switch this on: Terminal may control your Mac" --from right --color green --close-button
bigarrow start --element Add --role button --app "System Settings" \
  --text "Not in the list? Plus. Then find it." --from bottom-right --style ring --color orange --shape zigzag --size S
```

### Keynote: a three-step how-to

![Keynote: a purple ring, 1. Click Animate; an orange box, 2. Add an Effect; a teal zigzag on Play, 3. Press play. Bask in the applause.](docs/images/real/keynote.png)

```bash
bigarrow start --element Animate --app Keynote --role radiobutton --text "1. Click Animate" --from right \
  --style ring --color purple
bigarrow start --element "Add an Effect" --app Keynote --text "2. Add an Effect" --from right \
  --style box --corners sharp --color "#FF9F0A" --shape straight
bigarrow start --element Play --app Keynote --role button --text "3. Press play. Bask in the applause." \
  --from top --color teal --shape zigzag --size S
```

### Print dialog: helping Mom save a PDF

![TextEdit print dialog: a pink arrow, Mom, click PDF, then Save as PDF, and a small black one on Cancel: Not this one, Mom](docs/images/real/print.png)

```bash
bigarrow start --element PDF --role button --app TextEdit \
  --text "Mom, click PDF, then Save as PDF" --from bottom --color pink --border white-black
bigarrow start --element Cancel --role button --app TextEdit \
  --text "Not this one, Mom" --from bottom-right --color black --size S
```

### Chrome: the right tab out of 14

![Chrome, three windows, 14 tabs, a big indigo sign: It's this tab, not the other 13](docs/images/real/chrome.png)

```bash
bigarrow start --app "Google Chrome:Sourdough" --element "Sourdough - Wikipedia" --role radiobutton \
  --text "It's this tab, not the other 13" --from top --shape zigzag --color "#5856D6" --size L
```

`--app "App:tab title"` raises the window and selects the tab first.

### Finder: "no, the other grid icon"

![Finder: a black ring on the icon view button, Not this one, and a green box on the Group button: No, the other grid icon. This one.](docs/images/real/finder.png)

```bash
bigarrow start --element "icon view" --role radiobutton --app Finder \
  --text "Not this one" --from top-left --style ring --color black --size S
bigarrow start --element Group --role menubutton --app Finder \
  --text "No, the other grid icon. This one." --from top --style box --color green
```

### A real guide: allow screen recording

<a href="docs/guides/allow-screen-recording/how-to-allow-screen-recording-on-a-mac.pdf"><img src="docs/images/guide-pdf-preview.png" width="600" alt="The guide as a 6-page PDF: page thumbnails on the left, page 1 large on the right, How to allow screen recording on a Mac, step 1 with an arrow at Privacy &amp; Security"></a>

The whole guide as a 6-page PDF, every screenshot an arrow an agent drew. [Download the PDF](docs/guides/allow-screen-recording/how-to-allow-screen-recording-on-a-mac.pdf) or [read it here](docs/guides/allow-screen-recording/README.md).

## Copy & paste

`{{value}}` in the sign becomes a copy button. Click, paste.

![A made-up sign-in page asks for a PIN; a blue arrow with a yellow border points at the empty field: Franz, copy & paste the PIN 482913 here, the PIN on a yellow copy button](docs/images/real/copy-pin.png)

![The same moment after the click: the copy icon is a check, the PIN 482913 is pasted into the field](docs/images/real/copy-pin-copied.png)

```bash
bigarrow start --element "PIN code" --role textfield --app "Google Chrome:Acme sign-in" --from right \
  --color blue --border-color yellow --text-color yellow --text "Franz, copy & paste the PIN {{482913}} here"
```

## Cue cards: values, secrets, answers

When the human needs more than one value, a secret, or has to answer, the agent holds up a cue card: a floating window with copy buttons, an X, and nothing that takes your focus. `bigarrow wait` tells the agent what you did. A card with questions closes itself once you have answered them all (`--keep` keeps it until its X); a card with only values stays until you click its X or the agent closes it (`bigarrow stop --cards`). No time limit, and typing to your agent does not close it.

![Four cue cards rendered by bigarrow: a Hetzner login with user, masked password and console link; a choice between three headers in dark mode; a live 2FA code with its countdown; a deploy's progress with a Cancel button](docs/images/cards.png)

```bash
bigarrow card --title "Franz, log in to Hetzner" --app "Google Chrome" --field "User=franz@example.com" \
  --secret "Password=keychain:hetzner/franz" --link https://console.hetzner.cloud --button "done=I'm in"
bigarrow wait   # {"result":"button","value":"done","copied":["User","Password"],"after":41.2,...}
```

- **Secrets stay secret.** `--secret` reads from `pass:`, `keychain:`, `op:` (1Password), `env:` or `file:`, never from the command line, where `ps` shows it to every user. Dots until you reveal them, copied as concealed (clipboard managers skip it), gone from the clipboard after 30 s, never in the reply. A card with a secret asks macOS to keep it out of screenshots and recordings (`screencapture` on macOS 27 leaves it out).
- **Questions while you are away.** `--ask` for a typed answer, `--choice` for options, `--button` for decisions. The agent gets JSON with every answer and exit 0 once you have answered, or exit 1 when you closed the card first.
- **Arrow and card together.** A row can point at where its value goes; copy the user name and the arrow shows the user field, copy the password and it moves on. `bigarrow start ... --card card.json` puts an arrow and a card up as one.
- 13 row types (field, code, link, text, live 2FA code, QR, image, file to drag out, choice, question, checklist, progress, buttons) in a JSON card; [20 real use cases](docs/cards/) as files.

### Funny cue cards

Real apps on a real Mac, an arrow and a card each, clicked and typed into for real, staged by `scripts/card-scenes.sh`. The situations are made up. The buttons work.

#### Buttons: delete node_modules

![Finder shows a folder my-app; a green arrow rings node_modules with the sign 847,293 files live here. Rent-free. Beside it a green card: Franz, delete node_modules? 3.4 GB, 847,293 files. You have opened none of them. Buttons: Let me grieve first, Yes, finally](docs/images/cards-real/node-modules.png)

```bash
bigarrow card --title "Franz, delete node_modules?" --note "**3.4 GB**, 847,293 files. You have opened none of them." --button "Let me grieve first" --button "Yes, finally" --app Finder --color green
```

#### A choice: more arrows

![A dialog Arrow budget: Franz has used 40 of 40 arrows this week. A purple arrow on its Ask Franz button says Too late. He picked. The purple card Franz, approve 3 more arrows? shows the picked option One, but bigger lit and Sent. Close this card with the X.](docs/images/cards-real/arrows.png)

```bash
bigarrow card --title "Franz, approve 3 more arrows?" --choice "Yes, 3 more" --choice "Make it 12" --choice "One, but bigger" --keep --color purple
```

#### A question: lunch

![A canteen page lists Mystery casserole, Soup of the day (yesterday) and Salad, which is lettuce; an orange arrow on Mystery casserole says Brave. Not recommended. The orange card Franz, what do you want for lunch? has the answer Anything but the casserole typed in and a Send button.](docs/images/cards-real/lunch.png)

```bash
bigarrow card --title "Franz, what do you want for lunch?" --ask "Orders close at 11:30. The agent cannot taste, so you choose." --color orange
```

#### A checklist: Friday deploy

![A dialog: Deploy to production? It is Friday, 17:55. A blue arrow on Deploy says Only when all five are ticked. The blue card Franz, Friday deploy checklist has Tests are green, Rollback plan written and Team told ticked, Phone charged for the weekend and Inner peace found still open.](docs/images/cards-real/deploy.png)

```bash
bigarrow card - <<< '{"title": "Franz, Friday deploy checklist", "rows": [{"type": "checklist", "items": [{"id": "tests", "label": "Tests are green"}, {"id": "rollback", "label": "Rollback plan written"}, {"id": "team", "label": "Team told"}, {"id": "phone", "label": "Phone charged for the weekend"}, {"id": "peace", "label": "Inner peace found"}]}]}'
```

#### A value and where it goes: the coffee machine

![A coffee machine page with a PIN field and a Brew button; a brown arrow from the card rings the PIN field with the sign Paste the PIN here, then Brew. The brown card Franz, coffee is one PIN away has Machine PIN 4711 and Strength Yes, each with a copy button, and Cups today: 4. The agent is not judging.](docs/images/cards-real/coffee.png)

```bash
bigarrow card - <<< '{"title": "Franz, coffee is one PIN away", "app": "Google Chrome", "rows": [{"type": "field", "label": "Machine PIN", "value": "4711", "point": {"element": "PIN", "text": "Paste the PIN here, then Brew"}}]}'
```

#### Copy buttons: the git command you search every week

![A search page: how to undo the last git commit, You searched for this 52 times this year; a teal arrow on the query says No need. The agent remembers. The teal card Franz, it's this one. Again. shows git reset --soft HEAD~1 just copied, with its check and a Copied pill, and Searched this year: 52 times.](docs/images/cards-real/git.png)

```bash
bigarrow card --title "Franz, it's this one. Again." --code "git reset --soft HEAD~1" --field "Searched this year=52 times" --color teal
```

## What is this actually for?

Fair question. Arrows have existed since roughly the Paleolithic. What changed: agents now do real work on your Mac, and sooner or later hit a step **only a human may do**, or one the human wants to learn.

- **"Click Allow."** Permission prompts, OAuth consent, "Open with...?". The agent finds the button but must not, or cannot, press it. It can point.
- **"Your turn."** 2FA, CAPTCHAs, passkeys, payments, signatures. It points, you decide, it continues.
- **"Paste this."** A code, a URL, a command: on the sign with a [copy button](#copy--paste).
- **"Log in, the captcha is yours."** User, password, 2FA code and the link on a [cue card](#cue-cards-values-secrets-answers), the arrow on the field each one goes into.
- **"Which one?"** A question or a choice on a card while you are away from the terminal; the agent gets your answer as JSON.
- **"I need you, and you're making coffee."** `--say` reads the sign aloud. Your Mac will literally call you back to your desk.
- **"Show me how."** Ask how to do something in Blender, and the agent points at each control in turn. A product tour, minus the product.
- **Helping someone else.** On a parent's Mac or over a screen share, pointing beats "the button at the top, no, the other top".
- **Demos and docs.** Highlight while recording, or render straight to a PNG with `--png`.
- **Debugging coordinates.** Point at your Accessibility or Peekaboo coordinates and look. `--dry-run --json` says where it *would* point.

Not a screen annotator, not a click bot, not a screenshot tool, not a password manager. It never clicks, types or captures. It points, and holds up a card. Deliberately.

## Install

```bash
brew install franzenzenhofer/tap/bigarrow
bigarrow install-skill          # teaches Claude Code (~/.claude/skills) and Codex (~/.agents/skills)
```

From source: `swift build -c release` (the Command Line Tools or Xcode, Swift 6, macOS 14+), binary at `.build/release/bigarrow`. The binary is pure Swift; `scripts/` only records screenshots and runs tests.

On Windows or Linux? [see-the-arrow](https://github.com/chocodev11/see-the-arrow) brings the same arrow there (Rust, MIT): an agent points at each step, you click, and it finds buttons by name or, in apps like Blender that draw their own interface, in a screenshot. More in the [FAQ](#windows-or-linux).

## The three commands an agent needs

```bash
bigarrow point --element "Allow" --app "System Settings" --text "Franz, click Allow"   # by label
bigarrow point --at 760,500 --text "Franz, click HERE"                                 # by coordinate
bigarrow start --window "Safari:Inbox" --text "This window" && bigarrow stop            # until stopped
```

Every arrow ends by itself. Nobody has to clean up after an agent that forgot:

| | |
|---|---|
| Time limit | `--duration 10` (`point` 8 s, `start` 300 s, `0` = no limit) |
| Start and stop | `start` returns at once; `stop` (or `stop --all`) removes it |
| The agent goes away | the arrow ends with the agent process that drew it (`CLAUDE_PID` or `BIGARROW_OWNER_PID`) |
| The human answers | `bigarrow stop --hook` as a Claude Code `UserPromptSubmit` hook clears that session's arrows |
| The human closes it | `--close-button` (opt-in) |

Targets: `--at X,Y`, `--rect X,Y,W,H`, `--mouse`, `--window App[:title]`, `--element Label --app App`, `--peekaboo ID --snapshot see.json`. Coordinates are global top-left logical points, as Accessibility and Peekaboo report them; `--display N` makes them relative to one display.

`--app App[:window or tab title]` (or `--window`) first brings that app, window or Chrome/Safari tab to the front, because pointing at a window hidden behind your terminal is a special kind of unhelpful. If another app covers the target later, the arrow hides until it is visible again. `--no-raise` opts out. `bigarrow elements --app X` lists what `--element` can match; `bigarrow doctor` shows permissions and displays.

Every command takes `--json`. Exit codes: 0 ok, 1 a card ended without an answer, 2 bad input, 3 target not found, 4 permission missing. Agents love exit codes. Humans tolerate them.

## Looks

It is an arrow, so we spent an unreasonable amount of time on how it looks.

![Big arrows with signs: click here, sign here, over here, you are here, type your name, read this first, no the other one, click Allow](docs/images/hero.png)

![every border style and colour option: default white border with shadow, white-black, black, close button, custom border and text colours](docs/images/looks.png)

Six looks over white, macOS grey, dark, black, red and a busy web page:

![default, white-black, black, close button, custom colours and a black arrow, each over six backgrounds](docs/images/backgrounds.png)

![every style, shape, size and colour](docs/images/gallery.png)

- `--shape bend|straight|zigzag|spiral`: zigzag for when it is *really* urgent; spiral loops once around the sign, for when it must be impossible to miss
- `--style arrow|ring|box` (rings and boxes are outlines, the target stays visible), `--size S|M|L`, `--corners round|sharp`
- `--color red|orange|yellow|green|teal|blue|purple|pink|black|white|#RRGGBB`
- `--border shadow|white-black|black`: white border with drop shadow (default), a thin black edge instead of the shadow, or just a thin black outline
- `--border-color`, `--text-color`, `--edge-color`, `--close-color`, `--close-x-color`; left out, each picks a readable colour
- `{{value}}` in `--text` becomes a [copy button](#copy--paste); `--close-button` puts an X inside the sign's right end; `--follow` moves with a window or element; `--until-click` ends on a click on the target; `--say` speaks the sign
- Several arrows at once keep their signs out of each other's way

`scripts/gallery.py` renders every combination and zooms into every sign-to-shaft joint ([junctions](docs/images/junctions.png)), because a seam at the joint was, apparently, unacceptable.

## Creative arrows

Fake dialogs, real `bigarrow`, clean CI runner (`BACKDROP_ARGS=--cover scripts/funny-scenes.sh`). The dialogs are fake. The feelings are real.

### Delete node_modules: the easiest yes of your life

![Delete node_modules? Yes. Obviously.](docs/images/scenes/node-modules.png)

`--color green`, because some decisions are easy

### Cookie banner: the zigzag of mild urgency

![Cookie banner: Franz, nobody reads these either](docs/images/scenes/cookies.png)

`--shape zigzag --color orange`

### Software update: one lap of honour

![Software update: Twirl. Then click.](docs/images/scenes/spiral.png)

`--shape spiral`: once around the sign, then to the button

### 2FA: find your phone

![2FA: This is where you sigh and find your phone](docs/images/scenes/two-factor.png)

`--color purple`

### Friday deploy: the agent votes Cancel

![Friday deploy: the agent strongly suggests Cancel](docs/images/scenes/agent-needs-you.png)

`--close-button`, because the human gets the last word

### Save: three arrows, one button

![Three arrows, one Save button](docs/images/scenes/which-button.png)

three `start`s, one button, zero ambiguity

### Permissions: Terminal, not bigarrow

![Grant Accessibility to Terminal, not to bigarrow](docs/images/scenes/permissions.png)

`--style box --corners sharp`, plus a lesson about macOS permissions

## Starred by

[![GitHub stars](https://img.shields.io/github/stars/franzenzenhofer/big-arrow-on-the-screen?style=social)](https://github.com/franzenzenhofer/big-arrow-on-the-screen/stargazers) Nearly 400 stars in the first two days, from people whose GitHub profiles list **Apple, NVIDIA, AMD, SAP, Salesforce, ServiceNow, Booking.com, Mercedes-Benz, SUSE, Oxide Computer, Posit, CoreWeave, Weights & Biases, OpenRouter, Metabase, InstaDeep, Benchling, Stainless** and **Under Armour**, plus Stanford, Johns Hopkins, KTH and Oak Ridge National Laboratory.

## FAQ

[Permissions?](#does-it-need-screen-recording-or-accessibility) · [In front without focus?](#it-never-takes-the-focus-how-is-it-in-front) · [Steals my typing?](#will-it-steal-my-focus-while-im-typing) · [Click through?](#can-i-click-through-it) · [Displays and Spaces?](#multiple-displays-full-screen-apps-stage-manager-spaces) · [CPU?](#how-much-cpu-does-a-pulsing-arrow-cost) · [Web pages?](#does---element-work-inside-web-pages) · [Can it trick me?](#could-an-agent-use-this-to-trick-me) · [Token cost?](#why-a-skill-is-that-a-lot-of-tokens) · [Why not an annotation app?](#why-not-just-use-a-screen-annotation-app) · [Is it AI?](#is-it-ai) · [Windows or Linux?](#windows-or-linux) · [Do I need Xcode?](#do-i-need-xcode)

### Does it need Screen Recording or Accessibility?

**Drawing: no.** Some ways of finding the target do:

| You use | Permission |
|---|---|
| `--at`, `--rect`, `--mouse`, `--window App`, `--peekaboo`, `--app App` | none |
| `--element`, `elements`, `--until-click`, `--app App:title` | Accessibility |
| `--window App:title` (macOS 26 hides window titles) | Screen Recording, plus Accessibility to raise (not with `--no-raise`) |

macOS grants these to the app that started `bigarrow` (Terminal, iTerm2, Ghostty, VS Code, Claude), never to `bigarrow` itself, so switch on that app. `bigarrow doctor` names it; a missing permission exits with code 4 and names the app and the settings pane.

### It never takes the focus. How is it in front?

**On top and focused are two different things on macOS.** The arrow sits at screen-saver level, above windows, dialogs and full-screen apps, but never becomes the active window.

### Will it steal my focus while I'm typing?

**No.** That was the hardest bug in the project: `NSApplication.run()` quietly activates a process without a terminal. `bigarrow` pumps events itself, and the tests check that the frontmost app never changes.

### Can I click through it?

**Yes, everywhere except the sign and the shaft.** A click there removes the arrow (it dims under the pointer to say so). Clicks on the target or near the head go straight to the app, without taking the focus.

### Multiple displays? Full-screen apps? Stage Manager? Spaces?

**Yes, yes, yes, yes.** Negative coordinates included. Unplug a display while an arrow is on it and the arrow politely leaves. See the [verification matrix](docs/verification/multi-display.md).

### How much CPU does a pulsing arrow cost?

**1.4 % on a CI runner.** Core Animation does the work in the render server.

### Does `--element` work inside web pages?

**In Electron apps, yes. In Chrome, only with help.** Chrome needs `--force-renderer-accessibility` (or VoiceOver on); it ignores the usual request (verified October 2026). Chrome's own toolbar always works. Otherwise point at page coordinates, which the skill explains.

### Could an agent use this to trick me?

Say, by covering the Decline button? **Not beyond what it can already do.** An agent that runs shell commands as you can do far worse, so `bigarrow` gives it nothing new. Still, each checked by a test: boxes and rings are outlines, so the target stays visible; the sign keeps clear of the target (or overlaps it as little as possible); a click on sign or shaft removes the arrow; every arrow ends by itself. And the skill makes the sign say what your click does.

### Why a skill? Is that a lot of tokens?

**182 tokens, most of the time.** That is the skill's description, the only part the agent always sees. The instructions, 1,528 tokens (Anthropic's token-count API, Claude Opus 5.5), load only when it decides to point; pane ids and look flags (1,118 more) only when it needs them.

### Why not just use a screen annotation app?

**Those are for humans drawing on screens.** This is for programs pointing at things, from a shell, with exit codes. Twenty-six tools were checked first ([research](docs/research/)). None did this.

### Is it AI?

**No.** It is the least intelligent part of your AI stack, and proud of it.

### Windows or Linux?

Not from us, but two ports keep the same command line: [see-the-arrow](https://github.com/chocodev11/see-the-arrow) for Windows and Linux (X11), which adds a `screenshot` command and a step-by-step teach mode, and [Agent Pointer](https://github.com/castorhrio/agent-pointer-desktop) for Windows. Both MIT, both made by people from [issue #70](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/70).

### Do I need Xcode?

No. The Command Line Tools are enough to build it, and since 0.5.1 the Homebrew formula no longer asks for Xcode ([#71](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/71)).

## How we know it works

- 126 automated tests: geometry, placement, joints, a golden image, copy buttons, cue cards (format, secret sources, the RFC 6238 2FA vectors, the real login keychain), recorded window-server, Accessibility and Peekaboo fixtures, and the real window server (click-through, focus never moves, stop timing). CI runs macOS 15; also passed on macOS 26 and 27.
- 18 behaviour checks on a clean runner ([visual.yml](.github/workflows/visual.yml)): clicks on the X, a copy button (the clipboard holds the value, the arrow stays), `--until-click`, `--follow`, raising and `--no-raise`, hiding while covered, Chrome tab selection, owner exit, `stop --hook`, `--say`, full-screen, Stage Manager, Spaces, second and 2x displays, unplugging mid-arrow, CPU.
- 33 cue card checks with real clicks and typing ([card-check.sh](scripts/card-check.sh)): the focus never moves, buttons, the X, a typed answer, a choice, secrets (not in any process's arguments, not on disk, not in screenshots, concealed on the clipboard and gone after 30 s), one question closes the card, two need both answers, `--keep` stays until the X, only the X or `stop --pid`/`--cards` close a card (not the hook, `stop --all` or the agent exiting), arrow and card together.
- A fresh agent given only the skill and "show Franz where the Reload button in Chrome is" found it by label and built the right command ([transcript](docs/skill-tests/2026-10-08-chrome-reload.md)). It also found a bug, which is now a test.

## For agents (and the humans who configure them)

`skill/big-arrow/` (Agent Skills format, plus `agents/openai.yaml` for Codex) teaches the agent when to point, how to pick a target, to write a full sentence on the sign, to `--say` it when you are away, and to `stop` once you acted.

## Plan, decisions, research

`docs/plan/PLAN.md`, `docs/plan/TICKETS.md` (generated from `tickets.json`), `docs/decisions/`, `docs/research/`, `docs/verification/`, `docs/skill-tests/`, `CHANGELOG.md`.

## Prior art and thanks

Copy and check icons: [Feather](https://feathericons.com) (MIT, [notice](THIRD_PARTY_NOTICES.md)). Peekaboo (https://github.com/openclaw/Peekaboo) and Nameplate (https://github.com/steipete/Nameplate) by Peter Steinberger showed the overlay recipe and the skill packaging. Neither points with a labelled arrow. `bigarrow` reads Peekaboo's `see --json` as a target source.

## License

MIT. Point responsibly.
