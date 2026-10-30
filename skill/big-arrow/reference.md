# big-arrow reference

Detail that the common path in SKILL.md does not need. `bigarrow <subcommand> --help` lists
every flag.

## System Settings panes

`open "x-apple.systempreferences:<id>"`, verified on macOS 27. A wrong id does nothing and still
exits 0, so check the window title.

- `com.apple.preference.security?Privacy_` + `Accessibility` (titled "Device Control and Data
  Access" on macOS 27), `ScreenCapture`, `AllFiles`, `Automation`, `Camera`, `Microphone`,
  `ListenEvent`
- `com.apple.LoginItems-Settings.extension`, `com.apple.preference.notifications`,
  `com.apple.preference.displays`, `.keyboard`, `.network`, `.dock`, `.sound`,
  `com.apple.preferences.Bluetooth`, `com.apple.preferences.softwareupdate`

Web pages: open the URL itself, not the site's start page.

## Chrome page content

`--element` inside a page needs Chrome started with `--force-renderer-accessibility`. Otherwise
take the element's `getBoundingClientRect()` via Claude in Chrome and pass, at 100 % zoom,
`--rect (screenX + r.x),(screenY + outerHeight - innerHeight + r.y),r.width,r.height`
with `--app "Google Chrome:<tab title>"`.

## Coordinates from a screenshot

Global top-left points. From `tinyscreenshot`: display origin + pixel x (source width / output
width). `--display N` makes `--at` and `--rect` relative to display N (1-based, see
`bigarrow doctor`).

## Look

- `--color` red (default), orange, yellow, green, teal, blue, purple, pink, black, white or #hex
- `--style box|ring` marks without covering; `--size S|M|L`
- `--shape bend|straight|zigzag|spiral` (spiral loops once around the sign, then points)
- `--border shadow|white-black|black` (default: white border with drop shadow);
  `--border-color`, `--text-color`, `--edge-color`, `--close-color`, `--close-x-color`
- `--from <side>` preferred side of the sign; `--anchor center|title|top-left|...` with `--window`
- `--no-animation`, `--corners round|sharp`, `--voice` for `--say`
- `{{value}}` in `--text`: a copy button, several per sign; a click copies and keeps the arrow.
  A long value is shortened on screen and copied whole; `--say` speaks it; unbalanced braces
  exit 2. `--json` lists the frames as `copyButtons` and reports `copied` when the arrow ends

## Timing and ending

- `point` shows for 8 s (`--duration N`, 0 = until stopped); `start` = `point --detach --duration 300`
- `--until-click` ends when the human clicks the target, `--until-any-click` on any click
  (both need Accessibility); `--follow` moves with a `--window` or `--element` target
- `--no-raise` leaves windows as they are
- `stop --all` removes every arrow, `--pid` one, `--session <id>` one session's
- `--json` prints a machine-readable result, `--png <file>` renders offscreen instead of showing

## Cards

`bigarrow card` returns at once with `{"pid", "card", "controls"}`; `bigarrow wait [pid]` (or
`card --wait`) prints the reply once every question is answered; the card then closes itself
(`--keep` / `"keep": true`: it stays, showing "Sent", until its X). No time limit: a card without
questions stays until its X, or until you run `stop --pid <pid>` / `stop --cards` (`stop`, `--all`
and the hook leave cards alone). With `start ... --card`, `--duration` limits the arrow only. `card --update <pid>`
replaces the rows (progress); `--png` renders it offscreen, `--dry-run` checks it and prints it
with secrets hidden.

A JSON card (`bigarrow card card.json` or `bigarrow card - <<'EOF'`): `title`, `rows`, and
optionally `app`, `color`, `theme` (auto/light/dark), `say`, `keep`. Rows by `type`:

- `field` label + `value` or `secret` (a source; `"masked": true` hides a literal value)
- `code` (monospace, copy), `link` `url`, `text` `value` (inline Markdown), `qr` `value`
- `totp` `secret` (base32 seed or otpauth URI): a live 6-digit code with its countdown
- `image` / `file` `path` (a file the human drags onto an upload field)
- `choice` / `actions` `items: [{"id", "label", "detail"?, "style": "primary"?}]`
- `input` `label` (the question), `multiline`; `checklist` `items` (each may `point`)
- `progress` `value` (text) and `progress` (0 to 1)

`point` on a row or checklist item: `element`, `rect`, `at` or `window`, plus `app`, `role`,
`anchor`, `text` (the arrow's sign; default "Paste <label> here"). Unknown keys exit 2. The
reply: `result` (button, choice, input, checklist; or closed, stopped),
`value` (the last answer), `answers` (every answer by row id, else "row N"), `inputs`, `checked`,
`copied` (labels, never values), `opened`. Examples of 20 real
cases: `docs/cards/`.

