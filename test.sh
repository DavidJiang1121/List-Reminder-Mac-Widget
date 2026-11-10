#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
SCRATCH="$(mktemp -d /tmp/listreminder-tests.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
cp -R "$ROOT/Sources" "$ROOT/Tests" "$SCRATCH/"
xcrun swiftc -swift-version 5 -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target arm64-apple-macosx26.0 -module-cache-path "$SCRATCH/modules" "$SCRATCH/Sources/Store.swift" "$SCRATCH/Sources/DesktopWidget.swift" "$SCRATCH/Tests/Regression.swift" -o "$SCRATCH/Regression" -framework AppKit -framework Combine
"$SCRATCH/Regression" "$@"
