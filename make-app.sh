#!/bin/bash
# Build the release binary and assemble "Kaomoji Bar.app" next to this script.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="Kaomoji Bar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp .build/release/KaomojiBar "$APP/Contents/MacOS/KaomojiBar"
cp -R .build/release/KaomojiBar_KaomojiBar.bundle "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "built: $PWD/$APP"

# --install: replace the copy in /Applications and relaunch it.
if [ "${1:-}" = "--install" ]; then
    pkill -x KaomojiBar || true
    rm -rf "/Applications/$APP"
    ditto "$APP" "/Applications/$APP"
    rm -rf "$APP"
    open "/Applications/$APP"
    echo "installed: /Applications/$APP"
fi
