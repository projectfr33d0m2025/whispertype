#!/bin/bash

# build-release.sh - Build WhisperType for release distribution
# Usage: ./Scripts/build-release.sh

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="WhisperType"
SCHEME="WhisperType"
CONFIGURATION="Release"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/Release"
APP_PATH="${EXPORT_PATH}/${PROJECT_NAME}.app"

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

# Check if we're in the right directory
if [ ! -f "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
    echo_error "Could not find Xcode project. Please run from project root."
    exit 1
fi

# Check if whisper libraries are built
if [ ! -f "${PROJECT_DIR}/Libraries/whisper-built/lib/libwhisper.a" ]; then
    echo_error "whisper.cpp libraries not found. Please run ./Scripts/build-whisper.sh first."
    exit 1
fi

echo_info "Starting WhisperType Release Build..."
echo_info "Project Directory: ${PROJECT_DIR}"
echo_info "Build Directory: ${BUILD_DIR}"

# Clean build directory
echo_info "Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${EXPORT_PATH}"

# Resolve Swift Package Manager dependencies
echo_info "Resolving Swift Package Manager dependencies..."
cd "${PROJECT_DIR}"
xcodebuild -resolvePackageDependencies \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -quiet || {
    echo_warn "Package resolution had warnings, continuing..."
}

# Build the app
echo_info "Building ${PROJECT_NAME} in ${CONFIGURATION} mode..."
xcodebuild build \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    ONLY_ACTIVE_ARCH=NO \
    | grep -E "^(Build|Compile|Link|Sign|Copy|Process|Write|error:|warning:|\*\*)" || true

# Check if build succeeded
BUILD_PRODUCTS_PATH="${BUILD_DIR}/DerivedData/Build/Products/${CONFIGURATION}"
BUILT_APP_PATH="${BUILD_PRODUCTS_PATH}/${PROJECT_NAME}.app"

if [ ! -d "${BUILT_APP_PATH}" ]; then
    echo_error "Build failed. App not found at ${BUILT_APP_PATH}"
    exit 1
fi

# Copy app to export path
echo_info "Copying app to ${EXPORT_PATH}..."
cp -R "${BUILT_APP_PATH}" "${APP_PATH}"

# Ad-hoc sign the app for local distribution (required by macOS)
echo_info "Ad-hoc signing the app for distribution..."
codesign --force --deep --sign - "${APP_PATH}"

# Verify the signature
echo_info "Verifying code signature..."
codesign --verify --verbose "${APP_PATH}" && echo_info "Signature valid" || echo_warn "Signature verification had issues"

# Get version info
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${APP_PATH}/Contents/Info.plist")

echo ""
echo_info "=========================================="
echo_info "Build completed successfully!"
echo_info "=========================================="
echo_info "App: ${APP_PATH}"
echo_info "Version: ${VERSION} (${BUILD})"
echo_info ""
echo_info "Next steps:"
echo_info "  1. Test the app: open \"${APP_PATH}\""
echo_info "  2. Create DMG: ./Scripts/create-dmg.sh"
echo ""

# Print app size
APP_SIZE=$(du -sh "${APP_PATH}" | cut -f1)
echo_info "App Size: ${APP_SIZE}"
