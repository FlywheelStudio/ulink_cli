#!/bin/bash

# ULink CLI Build Script
# Usage: ./build.sh [--install] [--bump-version]

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
BUMP_VERSION=false

for arg in "$@"; do
    case $arg in
        --install|-i)
            INSTALL=true
            ;;
        --bump-version|-b)
            BUMP_VERSION=true
            ;;
        --help|-h)
            echo "ULink CLI Build Script"
            echo ""
            echo "Usage: ./build.sh [options]"
            echo ""
            echo "Options:"
            echo "  -i, --install       Install to $INSTALL_PATH after building"
            echo "  -b, --bump-version  Increment build number before building"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./build.sh                    # Just build"
            echo "  ./build.sh -i                 # Build and install"
            echo "  ./build.sh -b -i              # Bump version, build, and install"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            exit 1
            ;;
    esac
done

cd "$SCRIPT_DIR"

# Function to get current build number
get_build_number() {
    grep "static const String buildNumber" "$VERSION_FILE" | sed "s/.*'\([0-9]*\)'.*/\1/"
}

# Function to bump build number
bump_build_number() {
    local current_build=$(get_build_number)
    local new_build=$((current_build + 1))
    local today=$(date +%Y-%m-%d)

    echo -e "${YELLOW}Bumping build number: $current_build -> $new_build${NC}"

    # Update build number
    sed -i '' "s/static const String buildNumber = '[0-9]*'/static const String buildNumber = '$new_build'/" "$VERSION_FILE"

    # Update build date
    sed -i '' "s/static const String buildDate = '[0-9-]*'/static const String buildDate = '$today'/" "$VERSION_FILE"

    echo "$new_build"
}

# Bump version if requested
if [ "$BUMP_VERSION" = true ]; then
    NEW_BUILD=$(bump_build_number)
else
    NEW_BUILD=$(get_build_number)
fi

# Get version info
VERSION=$(grep "static const String version = " "$VERSION_FILE" | sed "s/.*'\([^']*\)'.*/\1/")
BUILD_DATE=$(grep "static const String buildDate = " "$VERSION_FILE" | sed "s/.*'\([^']*\)'.*/\1/")

echo -e "${GREEN}Building ULink CLI v$VERSION (build $NEW_BUILD)${NC}"
echo ""

# Run dart pub get
echo "Fetching dependencies..."
dart pub get 2>&1 | grep -v "^Resolving\|^Downloading\|^Changed\|^Got\|^  " || true

# Compile
echo "Compiling..."
dart compile exe bin/ulink.dart -o "$OUTPUT_BINARY" 2>&1 | grep -v "^Info:"

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
echo -e "${GREEN}ULink CLI v$VERSION (build $NEW_BUILD) - $BUILD_DATE${NC}"

# Verify
if [ "$INSTALL" = true ]; then
    echo ""
    echo "Verification:"
    "$INSTALL_PATH" --version
fi
