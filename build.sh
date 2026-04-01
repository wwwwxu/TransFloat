#!/bin/bash
set -e

echo "🔨 Building TransFloat..."
swift build -c release 2>&1

APP_NAME="TransFloat"
APP_DIR="$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

RESOURCES="$CONTENTS/Resources"

echo "📦 Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"

# Copy icon
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>TransFloat</string>
    <key>CFBundleDisplayName</key>
    <string>TransFloat</string>
    <key>CFBundleIdentifier</key>
    <string>com.vivixu.transfloat</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>TransFloat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>TransFloat needs to send keyboard events to copy selected text.</string>
</dict>
</plist>
PLIST

echo "✅ Built: $APP_DIR"
echo ""
echo "🚀 To run:  open TransFloat.app"
echo "📋 First time: Grant Accessibility permission in System Settings → Privacy & Security → Accessibility"
