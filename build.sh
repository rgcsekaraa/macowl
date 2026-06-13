#!/bin/bash
# Build macowl.app from main.swift and install it to /Applications.
#
#   ./build.sh          build + install to /Applications, then launch
#   ./build.sh --run    same, but also (re)launch even if already running
#
# Requires the Xcode command line tools (swiftc, codesign) - already present
# on a Mac that can run Swift.

set -euo pipefail

APP_NAME="macowl"
BUNDLE_ID="com.local.macowl"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SRC_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="/Applications/$APP_NAME.app"

echo "==> Cleaning previous build"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "==> Compiling main.swift"
swiftc -O \
    -o "$APP_DIR/Contents/MacOS/$APP_NAME" \
    "$SRC_DIR/main.swift"

echo "==> Generating app icon"
ICONSET="$BUILD_DIR/$APP_NAME.iconset"
rm -rf "$ICONSET"
swift "$SRC_DIR/makeicon.swift" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/$APP_NAME.icns"

echo "==> Writing Info.plist"
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>         <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>          <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>          <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>            <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleVersion</key>             <string>1.0</string>
    <key>CFBundleShortVersionString</key>  <string>1.0</string>
    <key>LSMinimumSystemVersion</key>      <string>13.0</string>
    <key>LSUIElement</key>                 <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing (needed for Login Items)"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Installing to $INSTALL_DIR"
# Quit any running copy so we can replace it.
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
sleep 1
rm -rf "$INSTALL_DIR"
cp -R "$APP_DIR" "$INSTALL_DIR"

echo "==> Launching"
open "$INSTALL_DIR"

echo "Done. Look for the owl icon in your menu bar."
