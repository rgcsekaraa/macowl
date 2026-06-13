#!/bin/bash
# Build a distributable macowl.dmg.
#
#   ./build-dmg.sh
#
# This compiles macowl.app into ./dist and packages it into ./dist/macowl.dmg
# with a drag-to-Applications shortcut. It does not touch /Applications or your
# running copy, so it is safe to run any time. Use build.sh if you just want to
# build and install locally.
#
# Requires the Xcode command line tools (swiftc, codesign, iconutil) and
# hdiutil, all of which ship with macOS.

set -euo pipefail

APP_NAME="macowl"
BUNDLE_ID="com.local.macowl"

# Version comes from $MACOWL_VERSION, else the latest git tag (v1.2.3 -> 1.2.3),
# else a sane default. This is what lets CI build the right version per tag.
# The git lookup must not be fatal (no tags is fine), hence the `|| true`.
VERSION="${MACOWL_VERSION:-}"
if [ -z "$VERSION" ]; then
    VERSION="$(git -C "$(dirname "$0")" describe --tags --abbrev=0 2>/dev/null || true)"
fi
VERSION="${VERSION#v}"
VERSION="${VERSION:-1.0.0}"

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SRC_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
STAGE_DIR="$DIST_DIR/dmg-stage"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Cleaning dist"
rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "==> Compiling main.swift"
swiftc -O \
    -o "$APP_DIR/Contents/MacOS/$APP_NAME" \
    "$SRC_DIR/main.swift"

echo "==> Generating app icon"
ICONSET="$DIST_DIR/$APP_NAME.iconset"
rm -rf "$ICONSET"
swift "$SRC_DIR/makeicon.swift" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/$APP_NAME.icns"
rm -rf "$ICONSET"

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
    <key>CFBundleVersion</key>             <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>  <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>      <string>13.0</string>
    <key>LSUIElement</key>                 <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Staging DMG contents"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_DIR" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

echo "==> Creating $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGE_DIR"

echo "Done. Distributable image: $DMG_PATH"
