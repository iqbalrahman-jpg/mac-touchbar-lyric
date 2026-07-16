#!/bin/zsh
set -euo pipefail

TAP="iqbalrahman-jpg/tap"
TAP_REPOSITORY="iqbalrahman-jpg/homebrew-tap"
APP_REPOSITORY="iqbalrahman-jpg/mac-touchbar-lyric"
CASK_TOKEN="touch-bar-lyrics"
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: ./scripts/update-homebrew-cask.sh <version> <sha256> [--dry-run]

Update the Touch Bar Lyrics cask in iqbalrahman-jpg/homebrew-tap.

Arguments:
  <version>   App version in X.Y.Z format.
  <sha256>    SHA-256 checksum of the release ZIP.

Options:
  --dry-run   Validate and display the cask change without committing or pushing.
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

if (( $# < 2 || $# > 3 )); then
    usage >&2
    exit 2
fi

VERSION="$1"
SHA256="${2:l}"
if (( $# == 3 )); then
    [[ "$3" == "--dry-run" ]] || fail "Unknown option: $3"
    DRY_RUN=1
fi

[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] \
    || fail "Version must use X.Y.Z format, for example 0.3.0"
[[ "$SHA256" =~ '^[0-9a-f]{64}$' ]] \
    || fail "SHA-256 must contain exactly 64 hexadecimal characters"

for command_name in brew git gh curl shasum perl; do
    command -v "$command_name" >/dev/null \
        || fail "Required command is unavailable: $command_name"
done

gh auth status >/dev/null
brew tap "$TAP"

TAP_ROOT="$(brew --repository "$TAP")"
CASK="$TAP_ROOT/Casks/$CASK_TOKEN.rb"
[[ -f "$CASK" ]] || fail "Cask is missing: $CASK"

cd "$TAP_ROOT"
[[ "$(git branch --show-current)" == "main" ]] \
    || fail "$TAP must be on its main branch"
[[ -z "$(git status --porcelain)" ]] \
    || fail "$TAP has uncommitted changes"

git fetch origin main
LOCAL_HEAD="$(git rev-parse HEAD)"
REMOTE_HEAD="$(git rev-parse refs/remotes/origin/main)"
[[ "$LOCAL_HEAD" == "$REMOTE_HEAD" ]] \
    || fail "$TAP must exactly match origin/main before updating"

CURRENT_VERSION="$(sed -nE 's/^[[:space:]]*version "([^"]+)"/\1/p' "$CASK")"
CURRENT_SHA256="$(sed -nE 's/^[[:space:]]*sha256 "([^"]+)"/\1/p' "$CASK")"

if [[ "$CURRENT_VERSION" == "$VERSION" ]]; then
    [[ "$CURRENT_SHA256" == "$SHA256" ]] \
        || fail "Cask version $VERSION exists with a different checksum"
    echo "$CASK_TOKEN $VERSION is already current in $TAP."
    exit 0
fi

CASK_BACKUP="$(mktemp "${TMPDIR:-/tmp}/touch-bar-lyrics-cask.XXXXXX")"
cp "$CASK" "$CASK_BACKUP"
CASK_CHANGED=0
CASK_COMMITTED=0
PUSHED=0
DOWNLOADED_ARCHIVE=""

cleanup() {
    local exit_status=$?
    if (( CASK_CHANGED && ! CASK_COMMITTED )); then
        cp "$CASK_BACKUP" "$CASK"
        echo "Restored the installed cask to version $CURRENT_VERSION."
    fi
    if (( exit_status != 0 && CASK_COMMITTED && ! PUSHED )); then
        echo "The Homebrew cask commit remains locally and was not pushed." >&2
        echo "Resolve the push problem, then run:" >&2
        echo "  git -C '$TAP_ROOT' push origin main" >&2
    fi
    if [[ -n "$DOWNLOADED_ARCHIVE" ]]; then
        rm -f "$DOWNLOADED_ARCHIVE"
    fi
    rm -f "$CASK_BACKUP"
    return "$exit_status"
}
trap cleanup EXIT

VERSION="$VERSION" SHA256="$SHA256" /usr/bin/perl -0pi -e '
    s{^(\s*version ")[^"]+(".*)$}{$1 . $ENV{VERSION} . $2}em;
    s{^(\s*sha256 ")[^"]+(".*)$}{$1 . $ENV{SHA256} . $2}em;
' "$CASK"
CASK_CHANGED=1

UPDATED_VERSION="$(sed -nE 's/^[[:space:]]*version "([^"]+)"/\1/p' "$CASK")"
UPDATED_SHA256="$(sed -nE 's/^[[:space:]]*sha256 "([^"]+)"/\1/p' "$CASK")"
[[ "$UPDATED_VERSION" == "$VERSION" && "$UPDATED_SHA256" == "$SHA256" ]] \
    || fail "Failed to update the cask version and checksum"

brew style "$TAP/$CASK_TOKEN"
brew audit --cask --strict "$TAP/$CASK_TOKEN"

echo ""
echo "Homebrew cask ready for review:"
echo "  Tap:      $TAP_REPOSITORY"
echo "  Version:  $VERSION"
echo "  SHA-256:  $SHA256"
echo ""
git --no-pager diff -- "$CASK"

if (( DRY_RUN )); then
    echo "Homebrew dry run complete. Nothing was committed or pushed."
    exit 0
fi

TAG="v$VERSION"
ARCHIVE_NAME="TouchBarLyrics-v${VERSION}-arm64.zip"
DOWNLOAD_URL="https://github.com/$APP_REPOSITORY/releases/download/$TAG/$ARCHIVE_NAME"
DOWNLOADED_ARCHIVE="$(mktemp "${TMPDIR:-/tmp}/TouchBarLyrics-$VERSION.XXXXXX.zip")"

curl --fail --location --silent --show-error \
    --output "$DOWNLOADED_ARCHIVE" \
    "$DOWNLOAD_URL"
DOWNLOADED_SHA256="$(shasum -a 256 "$DOWNLOADED_ARCHIVE" | awk '{print $1}')"
rm -f "$DOWNLOADED_ARCHIVE"
DOWNLOADED_ARCHIVE=""
[[ "$DOWNLOADED_SHA256" == "$SHA256" ]] \
    || fail "Published release checksum does not match the cask checksum"

git add -- "$CASK"
git commit -m "Update $CASK_TOKEN to $VERSION"
CASK_COMMITTED=1
git push origin main
PUSHED=1

rm -f "$CASK_BACKUP"
trap - EXIT

echo "Updated $TAP/$CASK_TOKEN to $VERSION."
