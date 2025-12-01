#!/bin/bash
#
# Build whisper.cpp static library for macOS
# This script builds libwhisper.a with Metal support for Apple Silicon
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WHISPER_DIR="$PROJECT_ROOT/Libraries/whisper.cpp"
BUILD_DIR="$WHISPER_DIR/build-macos"
OUTPUT_DIR="$PROJECT_ROOT/Libraries/whisper-built"

echo "=== Building whisper.cpp for macOS ==="
echo "Project root: $PROJECT_ROOT"
echo "Whisper source: $WHISPER_DIR"
echo "Build directory: $BUILD_DIR"
echo "Output directory: $OUTPUT_DIR"

# Check if whisper.cpp exists
if [ ! -f "$WHISPER_DIR/CMakeLists.txt" ]; then
    echo "Error: whisper.cpp not found at $WHISPER_DIR"
    echo "Please run: git submodule update --init --recursive"
    exit 1
fi

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Configure with CMake
echo ""
echo "=== Configuring CMake ==="
cd "$BUILD_DIR"

cmake "$WHISPER_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DGGML_ACCELERATE=ON \
    -DGGML_BLAS=ON \
    -DGGML_BLAS_VENDOR=Apple \
    -DGGML_OPENMP=OFF \
    -DGGML_NATIVE=OFF

# Build
echo ""
echo "=== Building ==="
cmake --build . --config Release -j$(sysctl -n hw.ncpu)

# Create output directory
echo ""
echo "=== Copying output files ==="
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/lib"
mkdir -p "$OUTPUT_DIR/include"

# Copy static libraries
echo "Copying libraries..."
find "$BUILD_DIR" -name "*.a" -exec cp {} "$OUTPUT_DIR/lib/" \;

# Copy headers
echo "Copying headers..."
cp "$WHISPER_DIR/include/whisper.h" "$OUTPUT_DIR/include/"
cp "$WHISPER_DIR/ggml/include/ggml.h" "$OUTPUT_DIR/include/"
cp "$WHISPER_DIR/ggml/include/ggml-alloc.h" "$OUTPUT_DIR/include/"
cp "$WHISPER_DIR/ggml/include/ggml-backend.h" "$OUTPUT_DIR/include/"
cp "$WHISPER_DIR/ggml/include/ggml-metal.h" "$OUTPUT_DIR/include/"
cp "$WHISPER_DIR/ggml/include/ggml-cpu.h" "$OUTPUT_DIR/include/"

echo ""
echo "=== Build complete ==="
echo "Libraries:"
ls -la "$OUTPUT_DIR/lib/"
echo ""
echo "Headers:"
ls -la "$OUTPUT_DIR/include/"
echo ""
echo "Add to Xcode:"
echo "  1. Library Search Paths: \$(PROJECT_DIR)/Libraries/whisper-built/lib"
echo "  2. Header Search Paths: \$(PROJECT_DIR)/Libraries/whisper-built/include"
echo "  3. Other Linker Flags: -lwhisper -lggml -lggml-base -lggml-cpu -lggml-metal"
echo "  4. Frameworks: Metal, MetalKit, Accelerate, Foundation"
