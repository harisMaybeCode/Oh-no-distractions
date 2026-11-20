#!/bin/bash
set -e
cd "$(dirname "$0")"
APP="Oh no, distractions.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -parse-as-library -O main.swift -o "$APP/Contents/MacOS/SiteBlocker"
cp Resources/* "$APP/Contents/Resources/"
cp art/meme.png "$APP/Contents/Resources/background.png"
ICONSET=$(mktemp -d)/AppIcon.iconset; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s art/panel-icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) art/panel-icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Oh no, distractions</string>
<key>CFBundleDisplayName</key><string>Oh no, distractions</string>
<key>CFBundleIdentifier</key><string>local.siteblocker</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleExecutable</key><string>SiteBlocker</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSAppleEventsUsageDescription</key><string>Needed to install the blocker with admin rights.</string>
</dict></plist>
PL
codesign --force --deep -s - "$APP"
echo "Built $APP"
