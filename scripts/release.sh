#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
INFO_PLIST="$ROOT/Resources/Info.plist"
PACKAGE_SCRIPT="$ROOT/scripts/package-release.sh"
RELEASE_DIR="$ROOT/build/releases"
REPOSITORY="iqbalrahman-jpg/mac-touchbar-lyric"
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: ./scripts/release.sh <version> [--dry-run]

Prepare and publish a complete Touch Bar Lyrics release.

Arguments:
  <version>   Release version in X.Y.Z format, for example 0.2.0.

Options:
  --dry-run   Build and validate the release without committing, tagging,
              pushing, or publishing. Info.plist is restored afterward.
  -h, --help  Show this help.
EOF
}

fail() {
    echo "Error: $1" >&2
    exit 1
}

if (( $# == 1 )) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if (( $# < 1 || $# > 2 )); then
    usage >&2
    exit 2
fi

VERSION="$1"
if (( $# == 2 )); then
    [[ "$2" == "--dry-run" ]] || fail "Unknown option: $2"
    DRY_RUN=1
fi

[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] \
    || fail "Version must use X.Y.Z format, for example 0.2.0"

TAG="v$VERSION"
ARCHIVE_NAME="TouchBarLyrics-v${VERSION}-arm64.zip"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"
ARCHIVE="$RELEASE_DIR/$ARCHIVE_NAME"
CHECKSUM="$RELEASE_DIR/$CHECKSUM_NAME"

for command_name in git gh swift codesign shasum perl; do
    command -v "$command_name" >/dev/null \
        || fail "Required command is unavailable: $command_name"
done

[[ -x "$PACKAGE_SCRIPT" ]] || fail "Missing executable: $PACKAGE_SCRIPT"

cd "$ROOT"

[[ "$(git branch --show-current)" == "main" ]] \
    || fail "Releases must be created from the main branch"
[[ -z "$(git status --porcelain)" ]] \
    || fail "The working tree must be clean before creating a release"

REMOTE_URL="$(git remote get-url origin 2>/dev/null)" \
    || fail "The origin Git remote is not configured"
[[ "$REMOTE_URL" == *"iqbalrahman-jpg/mac-touchbar-lyric"* ]] \
    || fail "origin does not point to $REPOSITORY"

echo "Checking Git and GitHub state..."
gh auth status >/dev/null
git fetch origin main --tags

LOCAL_HEAD="$(git rev-parse HEAD)"
REMOTE_HEAD="$(git rev-parse refs/remotes/origin/main)"
[[ "$LOCAL_HEAD" == "$REMOTE_HEAD" ]] \
    || fail "Local main must exactly match origin/main before releasing"

if git show-ref --verify --quiet "refs/tags/$TAG"; then
    fail "Git tag $TAG already exists"
fi
if gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
    fail "GitHub Release $TAG already exists"
fi

CURRENT_VERSION="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
CURRENT_BUILD="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleVersion' "$INFO_PLIST")"

[[ "$VERSION" != "$CURRENT_VERSION" ]] \
    || fail "Info.plist is already set to version $VERSION"
[[ "$CURRENT_BUILD" =~ '^[0-9]+$' ]] \
    || fail "CFBundleVersion must be numeric, got: $CURRENT_BUILD"

NEXT_BUILD=$(( CURRENT_BUILD + 1 ))
PLIST_BACKUP="$(mktemp "${TMPDIR:-/tmp}/TouchBarLyrics-Info.plist.XXXXXX")"
cp "$INFO_PLIST" "$PLIST_BACKUP"
PLIST_CHANGED=0
RELEASE_COMMITTED=0
PUSHED=0
RELEASE_CREATED=0

cleanup() {
    local exit_status=$?

    if (( PLIST_CHANGED && ! RELEASE_COMMITTED )); then
        cp "$PLIST_BACKUP" "$INFO_PLIST"
        echo "Restored Info.plist to version $CURRENT_VERSION (build $CURRENT_BUILD)."
    fi

    rm -f "$PLIST_BACKUP"

    if (( exit_status != 0 && RELEASE_COMMITTED && ! PUSHED )); then
        echo "The release commit and tag remain locally; nothing was published." >&2
        echo "Resolve the push problem, then run:" >&2
        echo "  git push --atomic origin main $TAG" >&2
        echo "  gh release create $TAG '$ARCHIVE' '$CHECKSUM' --repo $REPOSITORY --verify-tag --title 'Touch Bar Lyrics $TAG' --generate-notes" >&2
    elif (( exit_status != 0 && PUSHED && ! RELEASE_CREATED )); then
        echo "The release commit and tag were pushed, but the GitHub Release failed." >&2
        echo "Retry publication with:" >&2
        echo "  gh release create $TAG '$ARCHIVE' '$CHECKSUM' --repo $REPOSITORY --verify-tag --title 'Touch Bar Lyrics $TAG' --generate-notes" >&2
    fi

    return "$exit_status"
}
trap cleanup EXIT

echo "Updating Info.plist from $CURRENT_VERSION ($CURRENT_BUILD) to $VERSION ($NEXT_BUILD)..."
VERSION="$VERSION" NEXT_BUILD="$NEXT_BUILD" /usr/bin/perl -0pi -e '
    s{(<key>CFBundleShortVersionString</key>\s*<string>)[^<]*(</string>)}
     {$1 . $ENV{VERSION} . $2}e;
    s{(<key>CFBundleVersion</key>\s*<string>)[^<]*(</string>)}
     {$1 . $ENV{NEXT_BUILD} . $2}e;
' "$INFO_PLIST"
PLIST_CHANGED=1

UPDATED_VERSION="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
UPDATED_BUILD="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleVersion' "$INFO_PLIST")"
[[ "$UPDATED_VERSION" == "$VERSION" && "$UPDATED_BUILD" == "$NEXT_BUILD" ]] \
    || fail "Failed to update the version in Info.plist"

"$PACKAGE_SCRIPT"

[[ -f "$ARCHIVE" ]] || fail "Release archive was not created: $ARCHIVE"
[[ -f "$CHECKSUM" ]] || fail "Checksum was not created: $CHECKSUM"

EMBEDDED_VERSION="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' \
    "$ROOT/build/Touch Bar Lyrics.app/Contents/Info.plist")"
[[ "$EMBEDDED_VERSION" == "$VERSION" ]] \
    || fail "Built app contains version $EMBEDDED_VERSION instead of $VERSION"

(
    cd "$RELEASE_DIR"
    shasum -a 256 -c "$CHECKSUM_NAME"
)

echo ""
echo "Release ready for review:"
echo "  Version:  $VERSION"
echo "  Build:    $NEXT_BUILD"
echo "  Tag:      $TAG"
echo "  Archive:  $ARCHIVE"
echo "  Checksum: $CHECKSUM"
echo ""
git --no-pager diff -- "$INFO_PLIST"

if (( DRY_RUN )); then
    echo "Dry run complete. Nothing was committed, pushed, or published."
    exit 0
fi

if [[ ! -t 0 ]]; then
    fail "Publishing requires an interactive terminal for confirmation"
fi

echo -n "Publish $TAG to origin and GitHub? [y/N] "
IFS= read -r confirmation
case "${confirmation:l}" in
    y|yes)
        ;;
    *)
        echo "Release cancelled. Nothing was committed, pushed, or published."
        exit 0
        ;;
esac

git add -- "$INFO_PLIST"
git commit -m "chore: release $TAG"
git tag -a "$TAG" -m "Touch Bar Lyrics $TAG"
RELEASE_COMMITTED=1

git push --atomic origin main "$TAG"
PUSHED=1

gh release create "$TAG" \
    "$ARCHIVE" \
    "$CHECKSUM" \
    --repo "$REPOSITORY" \
    --verify-tag \
    --title "Touch Bar Lyrics $TAG" \
    --generate-notes
RELEASE_CREATED=1

PLIST_CHANGED=0
rm -f "$PLIST_BACKUP"
trap - EXIT

echo ""
echo "Published Touch Bar Lyrics $TAG successfully."
