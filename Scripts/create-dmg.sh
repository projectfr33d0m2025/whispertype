#!/bin/bash

# create-dmg.sh - Create distributable DMG for WhisperType
# Usage: ./Scripts/create-dmg.sh

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="WhisperType"
BUILD_DIR="${PROJECT_DIR}/build"
EXPORT_PATH="${BUILD_DIR}/Release"
APP_PATH="${EXPORT_PATH}/${PROJECT_NAME}.app"
DMG_DIR="${BUILD_DIR}/DMG"
DMG_STAGING="${DMG_DIR}/staging"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if app exists
if [ ! -d "${APP_PATH}" ]; then
    echo_error "App not found at ${APP_PATH}"
    echo_error "Please run ./Scripts/build-release.sh first."
    exit 1
fi

# Get version info
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${APP_PATH}/Contents/Info.plist")

DMG_NAME="${PROJECT_NAME}-${VERSION}"
DMG_TEMP="${DMG_DIR}/${DMG_NAME}-temp.dmg"
DMG_FINAL="${BUILD_DIR}/${DMG_NAME}.dmg"

echo_info "Creating DMG for ${PROJECT_NAME} v${VERSION}..."

# Clean up previous DMG builds
rm -rf "${DMG_DIR}"
rm -f "${DMG_FINAL}"
mkdir -p "${DMG_STAGING}"

# Copy app to staging
echo_info "Copying app to staging area..."
cp -R "${APP_PATH}" "${DMG_STAGING}/"

# Create symbolic link to Applications folder
echo_info "Creating Applications folder link..."
ln -s /Applications "${DMG_STAGING}/Applications"

# Create README for first-time users
cat > "${DMG_STAGING}/README.txt" << 'EOF'
WhisperType - Local Voice Transcription for macOS

INSTALLATION:
1. Drag WhisperType.app to the Applications folder
2. Open WhisperType from Applications
3. macOS may warn about an unsigned app - right-click and select "Open"
4. Grant Microphone permission when prompted
5. Grant Accessibility permission when prompted (System Settings > Privacy & Security)

FIRST USE:
1. Click the WhisperType icon in the menu bar
2. Go to Settings > Models and download a Whisper model
3. Use Option+Space (default) to start/stop recording

For more information, visit: https://github.com/YOUR_USERNAME/whispertype

EOF

# Calculate required size (app size + 10MB buffer)
APP_SIZE_KB=$(du -sk "${DMG_STAGING}" | cut -f1)
DMG_SIZE_KB=$((APP_SIZE_KB + 10240))

echo_info "Creating temporary DMG (${DMG_SIZE_KB}KB)..."

# Create temporary DMG
hdiutil create \
    -srcfolder "${DMG_STAGING}" \
    -volname "${PROJECT_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE_KB}k \
    "${DMG_TEMP}"

# Mount the temporary DMG
echo_info "Mounting temporary DMG..."
MOUNT_DIR="/Volumes/${PROJECT_NAME}"

# Unmount if already mounted
if [ -d "${MOUNT_DIR}" ]; then
    hdiutil detach "${MOUNT_DIR}" -force 2>/dev/null || true
fi

hdiutil attach "${DMG_TEMP}" -mountpoint "${MOUNT_DIR}"

# Set DMG window properties using AppleScript
echo_info "Configuring DMG appearance..."
osascript << EOF
tell application "Finder"
    tell disk "${PROJECT_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 900, 450}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item "${PROJECT_NAME}.app" of container window to {125, 170}
        set position of item "Applications" of container window to {375, 170}
        set position of item "README.txt" of container window to {250, 320}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Wait for Finder to update
sync
sleep 2

# Unmount
echo_info "Unmounting temporary DMG..."
hdiutil detach "${MOUNT_DIR}"

# Convert to compressed DMG
echo_info "Converting to compressed DMG..."
hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FINAL}"

# Clean up
echo_info "Cleaning up..."
rm -rf "${DMG_DIR}"

# Get final DMG size
DMG_SIZE=$(du -sh "${DMG_FINAL}" | cut -f1)

echo ""
echo_info "=========================================="
echo_info "DMG created successfully!"
echo_info "=========================================="
echo_info "DMG: ${DMG_FINAL}"
echo_info "Size: ${DMG_SIZE}"
echo_info "Version: ${VERSION} (${BUILD})"
echo ""
echo_info "Installation instructions:"
echo_info "  1. Double-click the DMG to mount it"
echo_info "  2. Drag WhisperType.app to Applications"
echo_info "  3. Right-click app and select 'Open' (first time)"
echo_info "  4. Grant required permissions"
echo ""

# Generate SHA256 checksum
echo_info "Generating SHA256 checksum..."
CHECKSUM=$(shasum -a 256 "${DMG_FINAL}" | cut -d' ' -f1)
echo "${CHECKSUM}  ${DMG_NAME}.dmg" > "${BUILD_DIR}/${DMG_NAME}.sha256"
echo_info "Checksum: ${CHECKSUM}"
echo_info "Checksum file: ${BUILD_DIR}/${DMG_NAME}.sha256"
