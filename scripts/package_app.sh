#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MacTaskScheduler"
BUNDLE_ID="${BUNDLE_ID:-com.local.${APP_NAME}}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$BUILD_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE_JPG="$ROOT_DIR/MacTaskScheduler.jpg"
ICON_FILE="$RESOURCES_DIR/AppIcon.icns"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

if [[ -f "$ICON_SOURCE_JPG" ]]; then
    ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    make_icon_png() {
        local width="$1"
        local height="$2"
        local output="$3"
        sips -s format png -z "$height" "$width" "$ICON_SOURCE_JPG" --out "$output" >/dev/null
    }

    make_icon_png 16 16 "$ICONSET_DIR/icon_16x16.png"
    make_icon_png 32 32 "$ICONSET_DIR/icon_16x16@2x.png"
    make_icon_png 32 32 "$ICONSET_DIR/icon_32x32.png"
    make_icon_png 64 64 "$ICONSET_DIR/icon_32x32@2x.png"
    make_icon_png 128 128 "$ICONSET_DIR/icon_128x128.png"
    make_icon_png 256 256 "$ICONSET_DIR/icon_128x128@2x.png"
    make_icon_png 256 256 "$ICONSET_DIR/icon_256x256.png"
    make_icon_png 512 512 "$ICONSET_DIR/icon_256x256@2x.png"
    make_icon_png 512 512 "$ICONSET_DIR/icon_512x512.png"
    make_icon_png 1024 1024 "$ICONSET_DIR/icon_512x512@2x.png"
    iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

codesign --force --deep --timestamp=none --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_DIR"

PLIST_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$CONTENTS_DIR/Info.plist")"
SIGNED_BUNDLE_ID="$(codesign -dv --verbose=4 "$APP_DIR" 2>&1 | awk -F= '/^Identifier=/{print $2; exit}')"

if [[ "$PLIST_BUNDLE_ID" != "$SIGNED_BUNDLE_ID" ]]; then
    echo "Bundle identifier mismatch after signing"
    echo "Info.plist: $PLIST_BUNDLE_ID"
    echo "CodeSign  : $SIGNED_BUNDLE_ID"
    exit 1
fi

echo "Packaged app: $APP_DIR"
echo "Bundle ID: $PLIST_BUNDLE_ID"
echo "Sign identity: $SIGN_IDENTITY"
