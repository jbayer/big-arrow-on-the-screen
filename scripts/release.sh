#!/bin/bash
# Releases version X.Y.Z: bumps the version, tags, waits for the release workflow, then
# writes Formula/bigarrow.rb into franzenzenhofer/homebrew-tap and pushes it.
# Usage: scripts/release.sh 0.1.0
set -euo pipefail
VERSION="$1"
TAG="v$VERSION"
REPO=franzenzenhofer/big-arrow-on-the-screen
TAP=franzenzenhofer/homebrew-tap
grep -q "## \[$VERSION\]" CHANGELOG.md || { echo "CHANGELOG.md has no [$VERSION] section" >&2; exit 2; }
[ -z "$(git status --porcelain)" ] || { echo "working tree is not clean" >&2; exit 2; }

sed -i '' "s/public static let current = \".*\"/public static let current = \"$VERSION\"/" Sources/BigArrowCore/BigArrowVersion.swift
swift build -c release
[ "$(.build/release/bigarrow --version)" = "bigarrow $VERSION" ]
git diff --quiet || git commit -qam "Release $TAG"
git tag -a "$TAG" -m "bigarrow $TAG"
git push -q origin main "$TAG"

echo "waiting for the release workflow"
sleep 15
RUN=$(gh run list -R "$REPO" -w release.yml -L 1 --json databaseId -q '.[0].databaseId')
gh run watch -R "$REPO" "$RUN" --exit-status > /dev/null

SHA=$(curl -sL "https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz" | shasum -a 256 | cut -d' ' -f1)
WORK=$(mktemp -d)
gh repo clone "$TAP" "$WORK/tap" -- -q
sed -e "s/@VERSION@/$VERSION/g" -e "s/@SHA256@/$SHA/g" scripts/bigarrow.rb.template > "$WORK/tap/Formula/bigarrow.rb"
git -C "$WORK/tap" add Formula/bigarrow.rb
git -C "$WORK/tap" commit -qm "bigarrow $VERSION"
git -C "$WORK/tap" push -q
echo "released $TAG; tap formula sha256 $SHA"
