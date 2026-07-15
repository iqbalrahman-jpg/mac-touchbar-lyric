#!/bin/zsh
set -euo pipefail

APP="$HOME/Applications/Touch Bar Lyrics.app"

osascript -e 'tell application id "com.iqbalrahman.TouchBarLyrics" to quit' 2>/dev/null || true
rm -rf "$APP"

echo "Removed $APP"
