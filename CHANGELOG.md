# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- README: "Funny cue cards", six real on-screen scenes (buttons, a choice, a question, a checklist, a row arrow, copy buttons), re-created by `scripts/card-scenes.sh`.

### Fixed
- A card with `app` now sits beside that app's window, as specified; it always fell back to the display's bottom-right corner because the window lookup returned a point, not the window's frame.

## [0.5.1] - 2026-10-26

### Changed
- A cue card closes only when the human clicks its X or the agent closes it on purpose: `bigarrow stop --pid <pid>` or the new `bigarrow stop --cards` (this session's cards). No time limit (`--duration` and the `duration` key are gone from cards); the prompt hook, `stop`, `stop --all` and the agent exiting leave cards alone. In 0.5.0 the hook closed a card the moment the human typed a reply. With `start ... --card`, `--duration` now limits only the arrow.
- Questions close the card: one question closes it once answered, several once all are answered (the reply's new `answers` has every one), `--keep` / `"keep": true` keeps it with a "Sent" banner until its X. A card with only values stays until the X. `card --wait` now detaches the card and waits, instead of holding the card's process.
- The card's header uses the arrow sign's font (SF Pro Rounded Heavy, 30 pt), centred, with more room; the card's border is the sign's contrast colour; more space between rows.
- README: links see-the-arrow (https://github.com/chocodev11/see-the-arrow), the same arrow for Windows and Linux, and the FAQ points to it and to Agent Pointer (Windows) (#70).
- Homebrew: the formula no longer requires Xcode; the Command Line Tools build it (#71, thanks to the reporter's tap PR).
- Cards animate what the human does: they slide in and fade out, buttons press down and light up under the pointer, a copy pops its icon, washes the row and shows a "Copied" pill, the eye and checklist boxes pop, and the chosen answer fills while the rest dims.

### Fixed
- An answered card at the bottom of the screen grew under the Dock; it now grows upwards there.

## [0.5.0] - 2026-10-26

### Added
- Cue cards: `bigarrow card` shows a floating card with the values, secrets and questions of a step: copy buttons, masked secrets with a reveal eye, live 2FA codes, links, QR codes, images, files to drag out, choices, a question, a checklist, progress and buttons. It never takes the focus, has an X, and ends by itself like an arrow (300 s, 120 s with a secret, `stop`, the hook, the owner exiting). Flags for the common case, a JSON card for everything (13 row types, unknown keys are bad input). Spec: `docs/plan/2026-10-26-cue-cards.md`; 20 real use cases in `docs/cards/`.
- `bigarrow wait [pid]` prints what the human did as JSON (button, option, typed text, ticks, which rows were copied, never their values); exit 0 for an answer, 1 when the card was closed or ran out. `card --wait` does the same in one call, `card --update <pid>` replaces the rows of a running card.
- Secrets never go on the command line: `--secret Label=source` with `pass:`, `keychain:<service>/<account>`, `op:`, `env:` or `file:`, or a JSON card on stdin; the detached card gets them through a pipe. Copied secrets are marked concealed and transient for clipboard managers and leave the clipboard after 30 s; a card with a secret stays out of screenshots.
- Arrow and card together: `point`/`start --card card.json` shows both as one; a row's `point` aims the arrow at where its value goes and moves on as the human copies the next one.
- `scripts/card-check.sh`: 25 on-screen checks (real clicks, typing, clipboard, secrets, lifetimes, arrows), run on the test Mac and in `visual.yml`; `scripts/card-gallery.py` renders the 20 use cases offscreen.
- Skill: "Cards: values, secrets, answers" (one value: a chip; more, a secret or a question: a card), the format in `reference.md`. Needs bigarrow 0.5.0.

### Changed
- The SVG reader also takes cubic curves (C, S), `<line>` and `<circle>`, for Feather's eye, eye-off, external-link, x, file, square and check-square icons.
- `scripts/testkit.swift`: `type`, `pasteboard`, and `windows` by pid.

## [0.4.6] - 2026-10-12

### Added
- Copy buttons: `{{value}}` in `--text` shows the value in the sign with a copy button. One click puts it on the clipboard (no permission needed), the icon turns into a check for 1.5 s, and the arrow stays where the value goes; a click elsewhere on the sign still removes it. Several per sign; long values are shortened on screen and copied whole. `--json` reports each chip's frame (`copyButtons`) and how often it was copied (`copied`). Icons from [Feather](https://feathericons.com) (MIT, `THIRD_PARTY_NOTICES.md`), drawn from their SVG source by a small SVG path reader. README section "Copy & paste": a made-up PIN in blue with a yellow border and text, before and after the click, recorded by `scripts/real-scenes.sh pin`.
- Skill: knows copy buttons. Anything to paste goes on the sign as `{{value}}`, a click on a copy button copies and keeps the arrow (only a click elsewhere on the sign removes it); long values, `--say` and unbalanced braces in `reference.md`. SKILL.md 1,528 tokens, reference.md 1,118 (Anthropic's token-count API).

### Fixed
- Copy buttons showed up as literal `{{value}}` text: the skill, linked from main, taught them before any release had them, and the installed binary printed the braces. SKILL.md now names the version it needs ("Needs bigarrow 0.4.6 or newer", upgrade with `brew upgrade`), and a test keeps that line from naming an unreleased version.
- `scripts/arthur-gui.sh` launches Ghostty with `--command=` (Ghostty 1.3 asks before every `-e` and unattended runs hung) and records the exit code even when the command calls `exit` (#62).

### Changed
- README: a one-line table of contents under the hero, and "Starred by": the companies and universities on the stargazers' public GitHub profiles, no names, no pictures.
- `main` is protected by a ruleset: no force pushes, no deletion.
- README: a video leads "Real apps, real use cases": an agent walks a human through "Click wallpaper to show desktop" in Desktop & Dock, six funny arrows, real clicks on macOS 27, recorded by `scripts/wallpaper-video.sh` (the Apple menu's account name and the desktop widgets pixelated).
- README: one subheadline per real-app shot (app and use case) and per creative scene, prose cut to a line; Install moves up under "What is it for?"; the FAQ is real questions and answers, one heading each, with a question index.
- The screen-recording guide also comes as a 6-page PDF (`scripts/guide-pdf.sh`, styled by `docs/guides/guide.css`); the README shows it as a viewer with page thumbnails, rendered offscreen by `scripts/pdf-preview.swift`.
- `scripts/testkit.swift`: `glide` (a hand-like pointer move) and `scroll` (wheel lines) for recordings.

## [0.4.5] - 2026-10-09

### Changed
- README: a quarter less prose, every section kept, the jokes too. Visuals first: real-app scenes, looks and creative arrows now come right after the hero, before the use-case list and the reference.
- Skill: 36% fewer tokens (SKILL.md 2,182 to 1,398, counted with Anthropic's token-count API), every rule kept, following the [Agent Skills best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices): one worked example instead of prose, rarely needed detail (System Settings pane ids, Chrome page coordinates, look and timing flags) moved to `skill/big-arrow/reference.md`, loaded only when needed.
- Docs: the screen-recording guide, the virtual-display README and the verification notes say the same in fewer words.

## [0.4.4] - 2026-10-09

### Changed
- README hero: a real desktop again (menu bar, Dock, a normal Chrome window with tabs and address bar) with nine arrows on the 2014-06-10 Hacker News front page, every one a different colour, shape or style, from every side, no headline covered. `scripts/hn-scene.sh` records it on the main display, no virtual display.
- README "Real apps, real use cases": every scene shows other looks (rings, boxes, zigzags, sharp corners, close button, white-black border, hex colours), most with a second or third arrow, and the menu bar is in every shot. `scripts/real-scenes.sh` crops to the main display's size, hides other Finder windows and reads the two version-dependent labels from `SETTINGS_ADD` and `FINDER_ICONS`.

## [0.4.3] - 2026-10-09

After the [Hacker News thread](https://news.ycombinator.com/item?id=50018817); triage in `docs/feedback/2026-10-09-hacker-news.md`.

### Fixed
- The box or ring around the target no longer drifts while it pulses: its layer scaled around the display's centre, so a box near a corner swam up to 55 pt off its target and back. Found by @jarombouts in #37 (#38).
- `--window` on a window left half off every display (after unplugging one) points at its visible part instead of failing with "outside every display".

### Changed
- Skill: when a click approves, grants, pays, signs, sends or deletes something, the sign says what happens (#42).
- Skill: open the exact System Settings pane or page first, then point; deep links verified on macOS 27 (#43, research in `docs/research/2026-10-09-system-settings-deep-links.md`).
- Permission errors name the pane macOS shows: on macOS 27 the Accessibility list is titled "Device Control and Data Access".
- README: plain-language tagline and permissions FAQ, new FAQ entries on focus, trust and token cost, use cases that lead with guiding and helping (#39, #44).
- New guide, `docs/guides/allow-screen-recording/`: how to allow screen recording on a Mac, six steps along Apple's own path, every screenshot a real arrow drawn by an agent on macOS 27, including the real password sheet.
- GitHub's language stats ignore `scripts/`; the binary is Swift only (#45).
- README: "Real apps, real use cases" with five real-app scenes recorded on macOS 27 by `scripts/real-scenes.sh` (System Settings, Keynote, TextEdit, Chrome, Finder) (#40); the hero is re-staged on a 2014 front page with short arrows that cross no headline (#41); the staged dialogs moved further down into "Creative arrows", one image per row.

## [0.4.2] - 2026-10-09

### Changed
- README: removed the spiral sheet next to the spiral scene.

## [0.4.1] - 2026-10-09

### Fixed
- `--shape spiral` curves out of the sign into its loop instead of turning a right angle where the stub meets the loop.

## [0.4.0] - 2026-10-09

### Added
- `--shape spiral`: the shaft leaves the sign, loops once around it on a widening loop that never touches the sign or itself, then sweeps to the target. The loop turns the way that ends heading towards the target, and placement reserves room for it, so it stays on screen.
- README: spiral sheet (`scripts/gallery.py` writes `spirals.png`) and a real-screen spiral scene.

## [0.3.0] - 2026-10-09

### Changed
- The default look is the white border with a drop shadow again, exactly as in 0.1.x.
- `--border shadow|white-black|black` replaces `--shadow`: `white-black` is the white border with a thin black edge outside it, `black` a thin black outline only.
- The X of `--close-button` is a white circle with the X in the arrow colour by default.

### Added
- `--border-color`, `--text-color`, `--edge-color`, `--close-color`, `--close-x-color`: every colour of the arrow can be set; left out, each picks a readable colour.
- The README shows every border style and colour option (`scripts/gallery.py` writes `looks.png`).

### Fixed
- The sign's black edge no longer cuts through the white border where the shaft meets the sign: it is drawn below every white border.
- The drop shadow is never cut off: PNG renders keep a margin wider than the shadow reaches, and signs keep 24 pt from the screen edge (a test fails if the shadow touches the PNG's edge).

## [0.2.1] - 2026-10-09

### Fixed
- The white contrast border is back (0.2.0 replaced it with a thin black outline by mistake). Without a shadow, a thin black edge now runs outside the white border; `--shadow` keeps the white border and uses the shadow instead of the black edge. Every black edge sits below every white border, so the flared joint has no seam.

## [0.2.0] - 2026-10-09

### Added
- `--app App[:window or tab title]` works with every target. A title that matches no window selects the tab with that title (Chrome, Safari) and raises its window.
- A bound arrow (`--app` or `--window`) hides while another app's window covers its target and comes back when the target is visible again.
- An arrow ends when the agent process that drew it exits (`CLAUDE_PID`, or `BIGARROW_OWNER_PID`); new dismissal reason `ownerGone`.
- `bigarrow stop --session ID` and `bigarrow stop --hook` (Claude Code hook payload on stdin, silent) clear the arrows of one agent session.
- A click on the sign or the shaft removes the arrow (it dims slightly under the pointer); clicks near the head and on the target pass through. No permission needed.
- `--shadow`: an optional short, soft drop shadow.

### Changed
- The target's app, window or tab comes to the front by default; `--no-raise` opts out. `--raise` is gone.
- `start`, `--close-button` and `--until-click` arrows end after 300 s unless `--duration` says otherwise; `--duration 0` is the only way to keep one up indefinitely.
- Look: a 1.5 pt black outline (white on near-black arrows) replaces the white contrast outline, and there is no drop shadow by default.
- `--close-button` draws the X inside the sign's right end instead of a separate panel on its corner, so it never covers text or hangs off the screen.
- Skill: one pattern (`start`, watch, `stop`), no close button by default, `--app` on every in-app target, the hook setup, about a third shorter.

## [0.1.2] - 2026-10-08

### Changed
- Skill: a "Time-critical" section and a mandatory trigger for expiring codes, login or payment pages that time out, and jobs waiting on the human (red, spoken, close button, `stop` afterwards).

## [0.1.1] - 2026-10-08

### Changed
- Several arrows at once keep their signs clear of each other (live arrows publish their sign frames); when the screen is crowded a sign moves further out, and overlaps as little as possible only when nothing else fits.
- `--from` is a preference: a side where the sign does not fit falls back to the roomiest side, so an arrow never covers its own target.
- When several running apps share a name (two Chrome instances), `--element`, `elements`, `front` and `--raise` use the one the human sees.
- `--element` asks Electron apps for their web content tree (`AXManualAccessibility`) and searches deeper and longer, for web pages.

### Fixed
- `--window` skips windows an app parks off-screen.

## [0.1.0] - 2026-10-08

### Added
- `bigarrow point`: a big arrow with a sign, click-through, non-activating, above full-screen apps, on every Space and display.
- Targets: `--at`, `--rect`, `--mouse`, `--window App[:title]`, `--element Label --app App` (Accessibility), `--peekaboo` / `--peekaboo-window` (Peekaboo 4.9.0 JSON).
- Lifetimes: `--duration`, `start` / `stop` (alias of `clear`), `--close-button`, `--until-click`, `--until-any-click`, `--follow`.
- Looks: `--shape bend|straight|zigzag`, `--style arrow|ring|box` (border-only marks), `--size S|M|L`, `--corners round|sharp`, ten colour presets and hex, automatic contrast, flared joint between sign and shaft, draw-on and pulse animations, Reduce Motion support.
- `front` and `--raise` bring the target's app and window to the front; `elements` lists what `--element` matches; `doctor` names the app that owns the permissions; `--say`; `--png`; `--dry-run`; `--json` everywhere; exit codes 0/2/3/4.
- The `big-arrow` skill for Claude Code and Codex, installed with `bigarrow install-skill`.
