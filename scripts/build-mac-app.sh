#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/ParaFlow.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUILD_DIR="$ROOT_DIR/.build/macos"
ICON_PATH="$ROOT_DIR/assets/LocalFlow.icns"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$BUILD_DIR"

if [[ ! -f "$ICON_PATH" ]]; then
  "$ROOT_DIR/scripts/build-app-icon.sh"
fi

swiftc "$ROOT_DIR/macos/LocalFlowApp.swift" \
  -framework Cocoa \
  -framework AVFoundation \
  -o "$MACOS_DIR/ParaFlow"

cp "$ICON_PATH" "$RESOURCES_DIR/LocalFlow.icns"
cp "$ROOT_DIR/assets/deep-tuck.wav" "$RESOURCES_DIR/deep-tuck.wav"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>ParaFlow</string>
  <key>CFBundleDisplayName</key>
  <string>ParaFlow</string>
  <key>CFBundleIdentifier</key>
  <string>local.flow.prototype</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleExecutable</key>
  <string>ParaFlow</string>
  <key>CFBundleIconFile</key>
  <string>LocalFlow</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>ParaFlow records your voice for local transcription.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>ParaFlow uses System Events to paste transcribed text into the focused field.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
echo "Logs: \$HOME/Library/Logs/ParaFlow.log"
