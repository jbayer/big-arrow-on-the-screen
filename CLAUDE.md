# CLAUDE.md - big-arrow-on-the-screen

macOS CLI (`bigarrow`) plus an agent skill (`big-arrow`, Claude Code and Codex) that draws a big arrow with a sign on the screen, click-through, auto-dismiss. Open source, MIT.

## State

Released 0.5.1 on 2026-10-26: cards close only by their X or `stop --pid`/`--cards`, header in the sign's font. 0.5.0: cue cards (`bigarrow card`, `wait`, `point/start --card`), spec `docs/plan/2026-10-26-cue-cards.md`, use cases `docs/cards/`, on-screen checks `scripts/card-check.sh`. Released 0.4.6 on 2026-10-12 (Homebrew `franzenzenhofer/tap/bigarrow`): copy buttons (`{{value}}` in `--text`, T51, Feather icons in `THIRD_PARTY_NOTICES.md`), the README TOC, "Starred by", the wallpaper video (`scripts/wallpaper-video.sh`), and the skill's "Needs bigarrow X or newer" gate (`SkillVersionTests`). 0.4.5 trimmed the README and docs by a quarter and the skill by a third (`skill/big-arrow/reference.md` holds the rarely needed detail). `main` has a ruleset: no force push, no deletion. 0.4.3 is the Hacker News round (M6, T41-T50, triage in `docs/feedback/`). Before it: everything in `docs/plan/PLAN.md` plus T31-T40, then bound and self-ending arrows (owner process, `stop --hook`, 300 s default, raise by default, tab selection, `--border` styles and colour options, `--shape spiral`), see `CHANGELOG.md`. `docs/plan/tickets.json` is the single source of truth for tickets; regenerate `TICKETS.md` and `report.html` with `scripts/render-tickets.py`, never edit those by hand.

## Rules

- Swift 6 strict concurrency, SwiftPM, AppKit + Core Animation. No SwiftUI for the overlay, no third-party dependencies except swift-argument-parser.
- Files target 200 lines, hard max 450. Functions under 30 lines, at most 4 parameters. No boolean parameters, no TODO comments, no commented-out code. `.swiftlint.yml` enforces this.
- No mocks. Tests hit the real window server and real Accessibility; skip with a printed reason when a permission is missing.
- Input coordinates are global top-left logical points. Flip against `NSScreen.screens[0].frame.height`, never `NSScreen.main`.
- The drawing path must never require a TCC permission. Only `--element`, `elements`, `--until-click`, `front --window` and an `--app`/`--window` title (raising a window or selecting a tab) may need Accessibility, and the error must name the responsible app (terminal or IDE).
- Every arrow must end by itself (time limit, owner exit, `stop`); never add a lifetime that can outlive the agent session by default.
- Cue cards are the exception (Franz, 2026-10-26): the human's X, the last answered question (unless `keep`), or the agent on purpose (`stop --pid`, `stop --cards`) closes one. No time limit; the prompt hook, `stop`, `stop --all` and the agent exiting leave it.
- Never call `NSApplication.run()`: its `finishLaunching()` activates a detached process and steals the focus. Use `OverlayApplication.runWithoutActivating()`.
- Gates before every commit: `swiftlint lint --strict`, `swift build -c release`, `swift test`. All green or no commit.
- Every image committed to the repo has C2PA metadata stripped and shows no personal content.
- English only in code, comments, commits and docs.
- The skill is symlinked from this checkout into `~/.claude/skills` and `~/.codex/skills`, so it is live the moment it lands on main, while the binary comes from Homebrew. A skill change that teaches a new flag or syntax bumps "Needs bigarrow X or newer" in `SKILL.md` to the release that ships it and is released right away (`SkillVersionTests` fails until `BigArrowVersion` reaches it, so bump that in the same change; `scripts/release.sh` then tags it as is).

## Where to test what

- **Franz's Mac (where he works): never draw, click, raise, speak or change displays.** Only build, unit tests, `--dry-run` and offscreen renders (`--png`, `scripts/gallery.py`). Plain `swift test` is safe: screen tests only run with `BIGARROW_SCREEN_TESTS=1`.
- **CI runner** (clean desktop, Accessibility and Screen Recording granted): `ci.yml` runs all tests with screen tests on; `visual.yml` (`gh workflow run visual.yml`) records screenshots, runs `scripts/behaviour-check.sh` (clicks, follow, raise, say, second display via `scripts/virtual-display`) and records the README demo GIF.
- **Arthur Mac** (the test Mac, macOS 27; reached over SSH, only from a machine whose `CLAUDE.local.md` describes it): `scripts/arthur-gui.sh '<command>'` runs a command in a Ghostty window there, with Ghostty's Accessibility, PostEvent and Screen Recording, and returns its output (e.g. `'BIGARROW_SCREEN_TESTS=1 swift test'`, `'scripts/hn-scene.sh /tmp/hn.png'`, `'BACKDROP_ARGS=--cover scripts/funny-scenes.sh /tmp/scenes'`). Pull and build there first. If its screen is locked, pixels come out black: unlock it as `CLAUDE.local.md` says; without that file, ask Franz. Machine-specific details (host aliases, unlock steps) go only in the gitignored `CLAUDE.local.md`, never in the repo. `backdrop --cover` hides Arthur's desktop, menu bar and notifications in shots.
- After any visual change: `python3 scripts/gallery.py .build/debug/bigarrow <out>` and look at `gallery.png` and `junctions.png` (every shape, side, size, colour; zoomed sign-to-shaft joints).

## Commands

```bash
swiftlint lint --strict && swift build -c release && swift test
swift run bigarrow point --at 760,500 --text "Franz, click HERE" --png /tmp/arrow.png   # offscreen
scripts/release.sh 0.2.0          # bump, tag, release workflow, Homebrew tap formula
```
