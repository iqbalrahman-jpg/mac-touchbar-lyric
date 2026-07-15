#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP_NAME="TouchBarLyrics"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/Touch Bar Lyrics.app"

cd "$ROOT"
swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$ROOT/.build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
echo "Run it with: open '$APP_BUNDLE'"
