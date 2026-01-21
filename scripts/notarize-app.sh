#!/bin/bash
# Notarize Voxa app with Apple
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.build"
APP_BUNDLE="${BUILD_DIR}/Voxa.app"

# Check if app exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    echo "Please run ./scripts/build-app.sh first"
    exit 1
fi

echo "Starting notarization process for Voxa..."

# Create a zip for notarization
ZIP_FILE="${BUILD_DIR}/Voxa.zip"
echo "Creating zip archive..."
cd "$BUILD_DIR"
/usr/bin/ditto -c -k --keepParent "Voxa.app" "Voxa.zip"

# Check if Apple ID credentials are in environment
if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ]; then
    echo ""
    echo "Please set your Apple ID credentials:"
    echo "  export APPLE_ID='your-apple-id@email.com'"
    echo "  export APPLE_TEAM_ID='9785XZK34L'"
    echo ""
    echo "You'll also need an app-specific password stored in keychain:"
    echo "  xcrun notarytool store-credentials 'notarytool-password' \\"
    echo "    --apple-id 'your-apple-id@email.com' \\"
    echo "    --team-id '9785XZK34L' \\"
    echo "    --password 'your-app-specific-password'"
    exit 1
fi

# Submit for notarization
echo "Submitting to Apple for notarization..."
echo "This may take several minutes..."

xcrun notarytool submit "$ZIP_FILE" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "@keychain:notarytool-password" \
    --wait

# Staple the notarization ticket
echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_BUNDLE"

echo ""
echo "✅ Notarization complete!"
echo "App is now notarized and ready for distribution"
echo ""
echo "Next step: Create DMG with ./scripts/create-dmg.sh"
