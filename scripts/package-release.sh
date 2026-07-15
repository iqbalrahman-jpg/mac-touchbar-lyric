#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
INFO_PLIST="$ROOT/Resources/Info.plist"
APP_BUNDLE="$ROOT/build/Touch Bar Lyrics.app"
BINARY="$APP_BUNDLE/Contents/MacOS/TouchBarLyrics"
RELEASE_DIR="$ROOT/build/releases"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "Invalid CFBundleShortVersionString: $VERSION" >&2
    exit 1
fi

ARCHIVE_NAME="TouchBarLyrics-v${VERSION}-arm64.zip"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"
ARCHIVE="$RELEASE_DIR/$ARCHIVE_NAME"
CHECKSUM="$RELEASE_DIR/$CHECKSUM_NAME"

cd "$ROOT"

echo "Running tests..."
swift test

echo "Building app..."
"$ROOT/scripts/build-app.sh"

ARCHITECTURE="$(file "$BINARY")"
if [[ "$ARCHITECTURE" != *"arm64"* || "$ARCHITECTURE" == *"x86_64"* ]]; then
    echo "Expected an arm64-only binary, got: $ARCHITECTURE" >&2
    exit 1
fi

MINIMUM_OS="$(vtool -show-build "$BINARY" | awk '$1 == "minos" { print $2; exit }')"
if [[ -z "$MINIMUM_OS" || "${MINIMUM_OS%%.*}" -lt 13 ]]; then
    echo "Expected a macOS 13+ deployment target, got: ${MINIMUM_OS:-unknown}" >&2
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

mkdir -p "$RELEASE_DIR"
rm -f "$ARCHIVE" "$CHECKSUM"

echo "Creating $ARCHIVE_NAME..."
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"

(
    cd "$RELEASE_DIR"
    shasum -a 256 "$ARCHIVE_NAME" > "$CHECKSUM_NAME"
)

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/touchbar-lyrics-release.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
ditto -x -k "$ARCHIVE" "$TEMP_DIR"
codesign --verify --deep --strict --verbose=2 "$TEMP_DIR/Touch Bar Lyrics.app"

echo ""
echo "Release artifacts created:"
echo "  $ARCHIVE"
echo "  $CHECKSUM"
echo ""
echo "Publish with:"
printf "  gh release create v%s \\\\\n" "$VERSION"
printf "    '%s' \\\\\n" "$ARCHIVE"
printf "    '%s' \\\\\n" "$CHECKSUM"
printf "    --repo iqbalrahman-jpg/mac-touchbar-lyric \\\\\n"
printf "    --title 'Touch Bar Lyrics v%s' --generate-notes\n" "$VERSION"
