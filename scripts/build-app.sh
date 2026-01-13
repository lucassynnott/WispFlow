#!/bin/bash
# Build WispFlow as a macOS app bundle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.build"
APP_NAME="WispFlow"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

# Parse arguments
BUILD_CONFIG="debug"
if [ "${1:-}" = "--release" ] || [ "${1:-}" = "-r" ]; then
    BUILD_CONFIG="release"
fi

echo "Building WispFlow ($BUILD_CONFIG)..."

# Build with Swift
cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIG"

# Create app bundle structure
echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${BUILD_CONFIG}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Copy Info.plist
cp "${ROOT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/"

# Set executable permissions
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "App bundle created at: ${APP_BUNDLE}"
echo ""
echo "To run: open ${APP_BUNDLE}"
echo "Or: ${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
