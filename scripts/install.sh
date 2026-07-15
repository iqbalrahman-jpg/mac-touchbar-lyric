#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SOURCE_APP="$ROOT/build/Touch Bar Lyrics.app"
DESTINATION="$HOME/Applications/Touch Bar Lyrics.app"

"$ROOT/scripts/build-app.sh"
mkdir -p "$HOME/Applications"
rm -rf "$DESTINATION"
cp -R "$SOURCE_APP" "$DESTINATION"
open "$DESTINATION"

echo "Installed $DESTINATION"
