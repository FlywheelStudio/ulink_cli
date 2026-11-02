#!/bin/bash

# Ulinkly CLI Build Script
# Usage: ./build.sh [--install]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/lib/config/version.dart"
OUTPUT_BINARY="$SCRIPT_DIR/ulink"
INSTALL_PATH="$HOME/bin/ulink"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
INSTALL=false

for arg in "$@"; do
    case $arg in
        --install|-i)
            INSTALL=true
            ;;
        --help|-h)
            echo "Ulinkly CLI Build Script"
            echo ""
            echo "Usage: ./build.sh [options]"
            echo ""
            echo "Options:"
            echo "  -i, --install       Install to $INSTALL_PATH after building"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./build.sh                    # Just build"
            echo "  ./build.sh -i                 # Build and install"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            exit 1
            ;;
    esac
done

cd "$SCRIPT_DIR"

# Build number is the git commit count
NEW_BUILD=$(git rev-list --count HEAD)

# Get version info
VERSION=$(grep "static const String version = " "$VERSION_FILE" | sed "s/.*'\([^']*\)'.*/\1/")
BUILD_DATE=$(date -u +%Y-%m-%d)

echo -e "${GREEN}Building Ulinkly CLI v$VERSION (build $NEW_BUILD)${NC}"
echo ""

# Run dart pub get
echo "Fetching dependencies..."
dart pub get 2>&1 | grep -v "^Resolving\|^Downloading\|^Changed\|^Got\|^  " || true

# Compile
echo "Compiling..."
dart compile exe -DBUILD_DATE="$BUILD_DATE" -DBUILD_NUMBER="$NEW_BUILD" bin/ulink.dart -o "$OUTPUT_BINARY" 2>&1 | grep -v "^Info:"

echo ""
echo -e "${GREEN}✓ Built successfully: $OUTPUT_BINARY${NC}"

# Install if requested
if [ "$INSTALL" = true ]; then
    echo ""
    echo "Installing to $INSTALL_PATH..."

    # Create bin directory if it doesn't exist
    mkdir -p "$(dirname "$INSTALL_PATH")"

    # Copy binary
    cp "$OUTPUT_BINARY" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"

    echo -e "${GREEN}✓ Installed to $INSTALL_PATH${NC}"
fi

echo ""
echo -e "${GREEN}Ulinkly CLI v$VERSION (build $NEW_BUILD) - $BUILD_DATE${NC}"

# Verify
if [ "$INSTALL" = true ]; then
    echo ""
    echo "Verification:"
    "$INSTALL_PATH" --version
fi
