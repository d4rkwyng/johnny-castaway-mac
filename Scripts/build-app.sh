#!/bin/zsh
# Builds Johnny Castaway.app from the SwiftPM JohnnyDemo executable.
# Output: dist/Johnny Castaway.app
# Usage: Scripts/build-app.sh [--install]   (--install copies to /Applications)
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product JohnnyDemo
BUILD_DIR=$(swift build -c release --show-bin-path)

APP="dist/Johnny Castaway.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp "$BUILD_DIR/JohnnyDemo" "$APP/Contents/MacOS/Johnny Castaway"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Johnny Castaway</string>
    <key>CFBundleIdentifier</key>
    <string>net.cyduck.JohnnyCastaway.app</string>
    <key>CFBundleName</key>
    <string>Johnny Castaway</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>GPL-3.0 — engine ported from jc_reborn. Not affiliated with Sierra/Dynamix.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign "${CODESIGN_ID:--}" "$APP"
echo "built $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/Johnny Castaway.app"
    cp -R "$APP" /Applications/
    echo "installed to /Applications/Johnny Castaway.app"
fi
