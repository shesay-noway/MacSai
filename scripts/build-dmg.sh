#!/bin/bash
# Build and package Mac Clean as a DMG
# Usage: ./scripts/build-dmg.sh [--notarize]

set -euo pipefail

APP_NAME="Mac Clean"
BUNDLE_ID="com.macclean.app"
VERSION="${VERSION:-1.0.0}"
BUILD_DIR=".build/release"
DMG_DIR=".build/dmg"
DMG_NAME="MacClean-${VERSION}.dmg"

echo "=== Building Mac Clean v${VERSION} ==="

# Step 1: Build release
echo "Building release..."
swift build -c release

echo "Build complete."

# Step 2: Create .app bundle
echo "Creating app bundle..."
APP_BUNDLE="${DMG_DIR}/${APP_NAME}.app"
rm -rf "${DMG_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/MacClean" "${APP_BUNDLE}/Contents/MacOS/"

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MacClean</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

# Copy icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "App icon added"
fi

# Create entitlements
cat > "${DMG_DIR}/entitlements.plist" << ENTITLEMENTS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
ENTITLEMENTS

echo "App bundle created at ${APP_BUNDLE}"

# Step 3: Create DMG
echo "Creating DMG..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    ".build/${DMG_NAME}"

echo "DMG created at .build/${DMG_NAME}"

# Step 4: Notarize (if requested)
if [[ "${1:-}" == "--notarize" ]]; then
    echo "Submitting for notarization..."
    echo "Note: Requires Apple Developer credentials configured with:"
    echo "  xcrun notarytool store-credentials 'MacClean'"
    echo ""

    xcrun notarytool submit ".build/${DMG_NAME}" \
        --keychain-profile "MacClean" \
        --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple ".build/${DMG_NAME}"
    echo "Notarization complete!"
fi

echo ""
echo "=== Build complete ==="
echo "DMG: .build/${DMG_NAME}"
echo "Size: $(du -h ".build/${DMG_NAME}" | cut -f1)"
