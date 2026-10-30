# Copy buttons in the sign (T51)

## Goal

An agent often needs the human to paste something: a `sudo` command it may not run, a URL, a
one-time code, an SSH key. Today the value sits in the terminal and the arrow points at the
field. With a copy button the value is on the sign itself: one click copies it, the arrow keeps
pointing at where it goes.

```bash
bigarrow start --window Terminal \
  --text "Franz, this needs your password. Copy {{sudo xcodebuild -license accept}} and paste it here"
```

The sign reads `Franz, this needs your password. Copy [sudo xcodebuild -license accept ⧉] and paste it here`.

## Decisions

- **Syntax: `{{value}}` inside `--text`.** The value stays part of the sentence, where the human
  reads it. Several per sign are allowed (user name and password). `{{` without `}}`, an empty
  `{{}}` or a stray `}}` is exit 2 with the reason: no guessing. No escape syntax; a sign that
  needs literal braces is not a real case.
- **The chip is one inline image (an `NSTextAttachment`).** It never wraps in the middle, and its
  rect comes from the same TextKit layout that draws the text, so the click area is exactly the
  pixels the human sees. A value wider than the sign is shown with a middle ellipsis; the full
  value is copied.
- **Look: like the close button.** The chip is filled with the text colour (white on red), the
  value in a bold monospaced font and the icon in the arrow colour. It reads as a button, works
  with every colour and `--text-color`, and the monospaced font tells `0` from `O`.
- **Icon: Feather Icons `copy` and `check`** (https://feathericons.com, MIT, Copyright (c)
  2013-2023 Cole Bemis), from the npm package `feather-icons@4.29.2`, `dist/icons/copy.svg` and
  `check.svg`. The SVG source is kept verbatim in `FeatherIcon.swift` and turned into a `CGPath`
  by a small SVG reader (`M L H V A Z`, absolute and relative, `rect`, `polyline`); it fails loudly
  on anything else. No SF Symbols (Apple licence), no new dependency. The licence text is in
  `THIRD_PARTY_NOTICES.md`.
- **Clicking a chip copies and keeps the arrow.** The human still needs the arrow to see where to
  paste. The icon turns into a check for 1.5 s, then back, so it can be copied again. A click
  anywhere else on the sign or shaft still removes the arrow, exactly as before. The pointer over
  a chip does not dim the arrow (dimming means "a click removes it").
- **No permission.** `NSPasteboard.general` needs none; the click reaches the chip through the
  existing pointer tracker (`ignoresMouseEvents` flips over the sign). The drawing path stays
  free of TCC.
- **Plain text everywhere else.** `--say`, the pid record (`bigarrow list`) and `--json` use the
  sentence with the values and without braces.

## Work

1. `BigArrowCore/SignText.swift`: parse `--text` into plain and copy segments. Unit tests.
2. `BigArrowCore/SVGPath.swift` + `FeatherIcon.swift`: SVG reader and the two icons. Unit tests
   (bounding boxes match the viewBox geometry; unknown commands throw).
3. `BigArrowOverlay/CopyChip.swift`: chip image (value, icon, copied state), attachment.
4. `SignRenderer`: TextKit layout, chips inline, chip rects and the copied-state text images in
   `SignImage`.
5. `ClickRegion`/`OverlayPanel`/`OverlayController`: hit test by click location; a chip click
   copies and swaps the sign text for 1.5 s; elsewhere dismisses.
6. `PointConfig`, `PointSession`: parse once, speak and record plain text.
7. Tests: offscreen chip rects inside the sign, copy without dismissing (unit, real
   pasteboard), golden render unchanged for signs without chips. On Arthur Mac: a real click on
   the chip puts the value on the clipboard and the arrow stays.
8. Docs: README section "Copy buttons" with a real use case (Terminal, a `sudo` command) and a
   small one, the skill (one rule plus example), `--help`, CHANGELOG, ticket T51.
