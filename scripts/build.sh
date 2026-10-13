#!/bin/bash
# Builds build/CopyHero.app
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/CopyHero.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/CopyHero "$APP/Contents/MacOS/CopyHero"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.kylar.copyhero</string>
    <key>CFBundleName</key><string>CopyHero</string>
    <key>CFBundleDisplayName</key><string>CopyHero</string>
    <key>CFBundleExecutable</key><string>CopyHero</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"
