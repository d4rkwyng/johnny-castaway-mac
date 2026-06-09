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
cp "$DYLIB" "$SAVER/Contents/MacOS/JohnnyCastaway"

# The bundle executable must not advertise a dylib install name.
install_name_tool -id "" "$SAVER/Contents/MacOS/JohnnyCastaway" 2>/dev/null || true

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
