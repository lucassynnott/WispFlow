#!/bin/bash
# Verify release build is ready for distribution
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.build"
APP_BUNDLE="${BUILD_DIR}/Voxa.app"
DMG_PATH="${BUILD_DIR}/Voxa-Installer.dmg"

echo "╔════════════════════════════════════════╗"
echo "║   Voxa Release Verification           ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if app exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found at $APP_BUNDLE"
    echo "   Run ./scripts/build-app.sh --release first"
    exit 1
fi

echo "✓ App bundle exists"

# Check code signature
echo ""
echo "Checking code signature..."
if codesign -v "$APP_BUNDLE" 2>/dev/null; then
    echo "✓ Code signature valid"

    # Show signature details
    AUTH=$(codesign -dvv "$APP_BUNDLE" 2>&1 | grep "Authority=Developer ID Application" | head -1)
    if [ -n "$AUTH" ]; then
        echo "  $AUTH"
    else
        echo "⚠️  Not signed with Developer ID (ad-hoc signature)"
    fi
else
    echo "❌ Code signature invalid"
    exit 1
fi

# Check entitlements
echo ""
echo "Checking entitlements..."
ENTITLEMENTS=$(codesign -d --entitlements - "$APP_BUNDLE" 2>&1)
if echo "$ENTITLEMENTS" | grep -q "com.apple.security.device.audio-input"; then
    echo "✓ Microphone entitlement present"
else
    echo "❌ Microphone entitlement missing"
    exit 1
fi

if echo "$ENTITLEMENTS" | grep -q "com.apple.security.automation.apple-events"; then
    echo "✓ Apple Events entitlement present"
else
    echo "❌ Apple Events entitlement missing"
    exit 1
fi

# Check hardened runtime
echo ""
echo "Checking hardened runtime..."
if codesign -dvv "$APP_BUNDLE" 2>&1 | grep "flags=" | grep -q "runtime"; then
    echo "✓ Hardened runtime enabled"
else
    echo "⚠️  Hardened runtime not enabled"
fi

# Check DMG
echo ""
if [ -f "$DMG_PATH" ]; then
    echo "✓ DMG exists"
    SIZE=$(ls -lh "$DMG_PATH" | awk '{print $5}')
    echo "  Size: $SIZE"

    # Check DMG signature
    if codesign -v "$DMG_PATH" 2>/dev/null; then
        echo "✓ DMG signature valid"
    else
        echo "⚠️  DMG signature invalid or not signed"
    fi
else
    echo "⚠️  DMG not found at $DMG_PATH"
    echo "   Run ./scripts/create-dmg.sh to create it"
fi

# Check notarization status
echo ""
echo "Checking notarization status..."
NOTARY_INFO=$(spctl -a -vv "$APP_BUNDLE" 2>&1 || true)
if echo "$NOTARY_INFO" | grep -q "accepted"; then
    echo "✓ App is notarized"
elif echo "$NOTARY_INFO" | grep -q "rejected"; then
    echo "❌ App notarization was rejected"
else
    echo "⚠️  App is not notarized"
    echo "   Run ./scripts/notarize-app.sh to notarize"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if codesign -v "$APP_BUNDLE" 2>/dev/null && \
   echo "$ENTITLEMENTS" | grep -q "com.apple.security.device.audio-input" && \
   echo "$ENTITLEMENTS" | grep -q "com.apple.security.automation.apple-events"; then
    echo "✅ App is ready for distribution"

    if echo "$NOTARY_INFO" | grep -q "accepted"; then
        echo "✅ App is notarized - ready for public release"
    else
        echo "⚠️  App is signed but not notarized"
        echo "   Notarization recommended for public distribution"
    fi
else
    echo "❌ App needs fixes before distribution"
fi

echo ""
