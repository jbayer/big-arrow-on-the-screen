#!/usr/bin/env python3
"""Render every cue card in docs/cards offscreen with `bigarrow card --png` (light, and the
first ones dark too) and lay them out on one contact sheet. Nothing is drawn on the screen.

Usage: scripts/card-gallery.py <bigarrow-binary> <out-dir>
Writes <out-dir>/<card>.png for every card and <out-dir>/cards.png.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHEET_TOOL = Path(__file__).with_name("contact-sheet.swift")
DARK = ["01-login", "09-choice", "11-checklist"]


def render(binary: str, card: Path, out: Path, theme: str) -> None:
    result = subprocess.run([binary, "card", str(card), "--theme", theme, "--png", str(out)],
                            cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"{card.name}: exit {result.returncode}: {result.stderr.strip()}")


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    binary, out = str(Path(sys.argv[1]).resolve()), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    entries = []
    for card in sorted((ROOT / "docs" / "cards").glob("*.json")):
        image = out / f"{card.stem}.png"
        render(binary, card, image, "light")
        entries.append(f"{image}:{card.stem}")
        if card.stem in DARK:
            dark = out / f"{card.stem}-dark.png"
            render(binary, card, dark, "dark")
            entries.append(f"{dark}:{card.stem} dark")
    sheet, tool = out / "cards.png", out / "contact-sheet"
    subprocess.run(["swiftc", "-O", str(SHEET_TOOL), "-o", str(tool)], check=True)
    env = dict(os.environ, CELL_ASPECT="1.25")
    subprocess.run([str(tool), str(sheet), "6", "460", *entries], check=True, env=env)
    print(sheet)


if __name__ == "__main__":
    main()
