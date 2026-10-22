#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
APP="$PWD/build/LogoerZoom.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/logo.png "$APP/Contents/Resources/logo.png"
cp Resources/background.json "$APP/Contents/Resources/background.json"
swiftc -O -target "$(uname -m)-apple-macosx15.2" -framework AppKit -framework CoreGraphics -framework ScreenCaptureKit \
    main.swift -o "$APP/Contents/MacOS/LogoerZoom"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.philip.LogoerZoom</string>
<key>CFBundleName</key><string>LogoerZoom</string>
<key>CFBundleExecutable</key><string>LogoerZoom</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>15.2</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
print -r -- "$APP"
