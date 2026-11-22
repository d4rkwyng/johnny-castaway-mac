#!/bin/zsh
# Builds JohnnyCastaway.saver from the SwiftPM JohnnySaver dylib.
# Output: dist/JohnnyCastaway.saver
# Usage: Scripts/build-saver.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=release
swift build -c $CONFIG --product JohnnySaver

BUILD_DIR=$(swift build -c $CONFIG --show-bin-path)
DYLIB="$BUILD_DIR/libJohnnySaver.dylib"
[[ -f "$DYLIB" ]] || { echo "error: $DYLIB not found" >&2; exit 1; }

SAVER=dist/JohnnyCastaway.saver
rm -rf "$SAVER"
mkdir -p "$SAVER/Contents/MacOS"

cp Sources/JohnnySaver/Info.plist "$SAVER/Contents/Info.plist"

# Version from the latest tag (v0.2.0 -> 0.2.0), used for both
# CFBundleShortVersionString and CFBundleVersion. Same derivation as
# build-app.sh; the checked-in plist's values are only placeholders.
VERSION=$({ git describe --tags --abbrev=0 2>/dev/null || true; } | sed 's/^v//')
VERSION=${VERSION:-0.0.0}
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $VERSION" \
    -c "Set :CFBundleVersion $VERSION" \
    "$SAVER/Contents/Info.plist"
cp "$DYLIB" "$SAVER/Contents/MacOS/JohnnyCastaway"

# The copied SwiftPM product is an MH_DYLIB, so it still has LC_ID_DYLIB.
# An empty install name is rejected by dyld on macOS 27 (issue #1).
install_name_tool -id "@rpath/JohnnyCastaway" "$SAVER/Contents/MacOS/JohnnyCastaway"
ID=$(otool -D "$SAVER/Contents/MacOS/JohnnyCastaway" | sed -n "2p")
[[ -n "$ID" ]] || { echo "error: empty LC_ID_DYLIB install name" >&2; exit 1; }

# Ad-hoc signature (arm64 requires a signature to load at all).
# Set CODESIGN_ID to a Developer ID for distribution.
codesign --force --deep --sign "${CODESIGN_ID:--}" "$SAVER"

echo "built $SAVER"

if [[ "${1:-}" == "--install" ]]; then
    DEST="$HOME/Library/Screen Savers"
    mkdir -p "$DEST"
    rm -rf "$DEST/JohnnyCastaway.saver"
    cp -R "$SAVER" "$DEST/"
    echo "installed to $DEST/JohnnyCastaway.saver"
    echo "If it was already selected, restart legacyScreenSaver:"
    echo "  killall -9 legacyScreenSaver 2>/dev/null || true"
fi
