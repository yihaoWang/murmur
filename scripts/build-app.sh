#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/app"
APP_NAME="Murmur"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
DMG_DIR="$PROJECT_DIR/.build/dmg"
DMG_PATH="$PROJECT_DIR/.build/$APP_NAME.dmg"

echo "==> Building release binary (arm64)..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64

BINARY="$(swift build -c release --arch arm64 --show-bin-path)/Murmur"

echo "==> Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

# Copy binary
cp "$BINARY" "$CONTENTS/MacOS/$APP_NAME"

# Copy SPM resource bundle (for Bundle.module at runtime)
cp -R "$(swift build -c release --arch arm64 --show-bin-path)/Murmur_Murmur.bundle" "$CONTENTS/Resources/"

# Copy app icon
cp "$PROJECT_DIR/Murmur/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"

# Copy Info.plist
cp "$PROJECT_DIR/Murmur/Info.plist" "$CONTENTS/Info.plist"

# Add required keys to Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_NAME" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.murmur.app" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0" "$CONTENTS/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$CONTENTS/Info.plist" 2>/dev/null || true

# Sign with entitlements
codesign --force --sign - --entitlements "$PROJECT_DIR/Murmur/Murmur.entitlements" "$APP_BUNDLE"

echo "==> Creating DMG..."
rm -f "$DMG_PATH"

create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "$APP_NAME.app" 150 190 \
  --app-drop-link 450 190 \
  --hide-extension "$APP_NAME.app" \
  --no-internet-enable \
  "$DMG_PATH" \
  "$APP_BUNDLE" \
  || true

echo "==> Done! DMG at: $DMG_PATH"
echo "    App bundle at: $APP_BUNDLE"
