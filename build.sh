#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
DEST="${1:-$ROOT/build}"
APP="$DEST/List Reminder.app"
SCRATCH="$(mktemp -d /tmp/listreminder-build.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -R "$ROOT/Sources" "$ROOT/Tools" "$SCRATCH/"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
xcrun swiftc -O -swift-version 5 -sdk "$SDK" -target arm64-apple-macosx26.0 -module-cache-path "$SCRATCH/modules" "$SCRATCH"/Sources/*.swift -o "$APP/Contents/MacOS/ListReminder" -framework AppKit -framework SwiftUI -framework Combine
xcrun swiftc -sdk "$SDK" -target arm64-apple-macosx26.0 -module-cache-path "$SCRATCH/modules" "$SCRATCH/Tools/Icon.swift" -o "$SCRATCH/icon"
"$SCRATCH/icon" "$SCRATCH/AppIcon.iconset"
/usr/bin/python3 "$SCRATCH/Tools/icns.py" "$SCRATCH/AppIcon.iconset" "$APP/Contents/Resources/AppIcon.icns"
cp "$SCRATCH/AppIcon.iconset/icon_512x512@2x.png" "$DEST/List Reminder Icon.png"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/ListReminder"
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
print "Built: $APP"
