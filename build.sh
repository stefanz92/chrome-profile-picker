#!/bin/bash
# Builds a universal "Chrome Profile Picker.app".
#   --install  copy it to ~/Applications and register it with macOS
#   --zip      also create build/ChromeProfilePicker.zip for a GitHub release
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Chrome Profile Picker"
EXECUTABLE="ChromeProfilePicker"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

INSTALL=false
ZIP=false
for argument in "$@"; do
    case "$argument" in
        --install) INSTALL=true ;;
        --zip) ZIP=true ;;
        *) echo "Unknown option: $argument" >&2; exit 1 ;;
    esac
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
    swiftc -O -swift-version 5 -target "$arch-apple-macos14" Sources/*.swift -o "$BUILD_DIR/$EXECUTABLE-$arch"
done
lipo -create "$BUILD_DIR/$EXECUTABLE-arm64" "$BUILD_DIR/$EXECUTABLE-x86_64" -output "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/Info.plist "$APP/Contents/Info.plist"

ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
swift Scripts/make-icon.swift "$BUILD_DIR/icon-1024.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$BUILD_DIR/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$BUILD_DIR/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP"
echo "Built $APP"

if $ZIP; then
    rm -f "$BUILD_DIR/$EXECUTABLE.zip"
    ditto -c -k --keepParent "$APP" "$BUILD_DIR/$EXECUTABLE.zip"
    echo "Zipped to $BUILD_DIR/$EXECUTABLE.zip"
fi

if $INSTALL; then
    pkill -x "$EXECUTABLE" || true
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    mkdir -p "$INSTALL_DIR"
    cp -R "$APP" "$INSTALL_DIR/"
    "$LSREGISTER" -f "$INSTALL_DIR/$APP_NAME.app"
    echo "Installed to $INSTALL_DIR/$APP_NAME.app"
fi
