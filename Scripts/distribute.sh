#!/bin/bash

# distribute.sh - Build WhisperType and create DMG for distribution
# Usage: ./Scripts/distribute.sh

set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${PROJECT_DIR}/Scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_header "WhisperType Distribution Builder"

# Check prerequisites
echo_info "Checking prerequisites..."

if [ ! -f "${PROJECT_DIR}/Libraries/whisper-built/lib/libwhisper.a" ]; then
    echo_error "whisper.cpp libraries not found."
    echo_error "Please run: ./Scripts/build-whisper.sh"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo_error "Xcode command line tools not found."
    echo_error "Please install: xcode-select --install"
    exit 1
fi

echo_info "Prerequisites OK"

# Step 1: Build Release
echo_header "Step 1: Building Release"
"${SCRIPTS_DIR}/build-release.sh"

# Step 2: Create DMG
echo_header "Step 2: Creating DMG"
"${SCRIPTS_DIR}/create-dmg.sh"

# Step 3: Summary
BUILD_DIR="${PROJECT_DIR}/build"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${BUILD_DIR}/Release/WhisperType.app/Contents/Info.plist")
DMG_NAME="WhisperType-${VERSION}.dmg"

echo_header "Distribution Complete!"

echo_info "Distribution files created:"
echo "  📦 ${BUILD_DIR}/${DMG_NAME}"
echo "  🔐 ${BUILD_DIR}/WhisperType-${VERSION}.sha256"
echo ""
echo_info "Ready for GitHub release!"
echo ""
echo "To create a release:"
echo "  1. Create a new release on GitHub"
echo "  2. Set tag to v${VERSION}"
echo "  3. Upload ${DMG_NAME}"
echo "  4. Copy contents from RELEASE_NOTES.md"
echo "  5. Update checksum in release notes"
echo ""
