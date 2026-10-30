#!/bin/bash
# Renders a guide's README.md to a PDF next to it, styled by docs/guides/guide.css.
# Links into the repo become GitHub links, so they still work once the PDF is downloaded; the
# guide's own "Also as a PDF" link is dropped.
# Screenshots go in as JPEG (quality 85, at most 1600 px wide) to keep the PDF small.
# Usage: scripts/guide-pdf.sh docs/guides/<guide> <file-name.pdf>
set -euo pipefail
GUIDE="$1"
PDF="$(pwd)/$GUIDE/$2"
REPO=https://github.com/franzenzenhofer/big-arrow-on-the-screen/blob/main
CSS="$(pwd)/docs/guides/guide.css"
WORK=$(mktemp -d)
for png in "$GUIDE"/*.png; do
  sips -s format jpeg -s formatOptions 85 --resampleWidth 1600 "$png" \
    --out "$WORK/$(basename "${png%.png}").jpg" > /dev/null
done
sed -E -e "s#\]\(\.\./\.\./\.\./([^)]*)\)#]($REPO/\1)#g" -e "s# Also as a \[PDF\]\($2\)\.##" -e 's#\]\(([^)/]*)\.png\)#](\1.jpg)#g' "$GUIDE/README.md" \
  | pandoc --from gfm --to html5 --standalone --section-divs \
      --metadata pagetitle="$(head -1 "$GUIDE/README.md" | sed 's/^# //')" --css "$CSS" --output "$WORK/guide.html"
weasyprint --base-url "$WORK/" "$WORK/guide.html" "$PDF" 2>&1 | grep -v 'user-select' || true
rm -r "$WORK"
echo "$PDF"
