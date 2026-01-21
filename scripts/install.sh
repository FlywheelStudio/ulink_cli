#!/bin/bash
#
# ULink CLI Installer for macOS and Linux
# Usage: curl -fsSL https://ulink.ly/install.sh | bash
#        curl -fsSL https://ulink.ly/install.sh | bash -s -- --ci
#        curl -fsSL https://ulink.ly/install.sh | bash -s -- --version v1.0.0

set -e

# Cleanup temp file on exit
cleanup() {
    [ -n "${tmp_file:-}" ] && rm -f "$tmp_file"
}
trap cleanup EXIT

REPO="FlywheelStudio/ulink_cli"
INSTALL_DIR="${HOME}/.local/bin"
BINARY_NAME="ulink"

# Colors (disabled in CI mode)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Flags
CI_MODE=false
VERSION="latest"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ci)
            CI_MODE=true
            RED=''
            GREEN=''
            YELLOW=''
            BLUE=''
            NC=''
            shift
            ;;
        --version)
            if [ -z "${2:-}" ] || [[ "$2" == -* ]]; then
                error "--version requires a version argument (e.g., v1.0.0)"
            fi
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            echo "ULink CLI Installer"
            echo ""
            echo "Usage:"
            echo "  curl -fsSL https://ulink.ly/install.sh | bash"
            echo "  curl -fsSL https://ulink.ly/install.sh | bash -s -- [options]"
            echo ""
            echo "Options:"
            echo "  --ci              Silent mode for CI environments"
            echo "  --version <ver>   Install specific version (e.g., v1.0.0)"
            echo "  -h, --help        Show this help"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

log() {
    if [ "$CI_MODE" = false ]; then
        echo -e "$1"
    fi
}

log_always() {
    echo -e "$1"
}

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            echo "linux"
            ;;
        *)
            error "Unsupported operating system: $(uname -s)"
            ;;
    esac
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)
            echo "x64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        *)
            error "Unsupported architecture: $(uname -m)"
            ;;
    esac
}

# Get download URL
get_download_url() {
    local os="$1"
    local arch="$2"
    local version="$3"

    local binary_name="ulink-${os}-${arch}"

    # Linux only has x64 builds
    if [ "$os" = "linux" ] && [ "$arch" = "arm64" ]; then
        error "Linux arm64 is not yet supported. Please use x64."
    fi

    if [ "$version" = "latest" ]; then
        echo "https://github.com/${REPO}/releases/latest/download/${binary_name}"
    else
        echo "https://github.com/${REPO}/releases/download/${version}/${binary_name}"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Global for cleanup trap
tmp_file=""

# Main installation
main() {
    log "${BLUE}ULink CLI Installer${NC}"
    log ""

    # Detect platform
    local os=$(detect_os)
    local arch=$(detect_arch)

    log "Detected: ${GREEN}${os}-${arch}${NC}"

    # Get download URL
    local url=$(get_download_url "$os" "$arch" "$VERSION")
    log "Downloading from: ${BLUE}${url}${NC}"

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Download binary
    tmp_file=$(mktemp)
    if command_exists curl; then
        curl -fsSL "$url" -o "$tmp_file" || error "Download failed. Check if the version exists."
    elif command_exists wget; then
        wget -q "$url" -O "$tmp_file" || error "Download failed. Check if the version exists."
    else
        error "Neither curl nor wget found. Please install one."
    fi

    # Install binary
    mv "$tmp_file" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

    log ""
    log "${GREEN}Installed to: ${INSTALL_DIR}/${BINARY_NAME}${NC}"

    # Check if INSTALL_DIR is in PATH
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        log ""
        log "${YELLOW}Note: ${INSTALL_DIR} is not in your PATH.${NC}"
        log ""
        log "Add it by running:"
        log ""

        local shell_name=$(basename "$SHELL")
        case "$shell_name" in
            zsh)
                log "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
                log "  source ~/.zshrc"
                ;;
            bash)
                log "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
                log "  source ~/.bashrc"
                ;;
            *)
                log "  export PATH=\"\$HOME/.local/bin:\$PATH\""
                ;;
        esac
    fi

    # Verify installation
    if [ -x "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        log ""
        log_always "${GREEN}ULink CLI installed successfully!${NC}"

        # Try to show version if in PATH
        if command_exists ulink; then
            log ""
            ulink --version 2>/dev/null || true
        fi
    else
        error "Installation verification failed"
    fi
}

main
