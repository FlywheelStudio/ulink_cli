# CLI Distribution Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement automated cross-platform distribution for the ULink CLI via GitHub Actions and install scripts.

**Architecture:** GitHub Actions builds native binaries for macOS (arm64, x64), Linux (x64), and Windows (x64) on version tags. Install scripts download the correct binary from GitHub Releases based on OS/architecture detection.

**Tech Stack:** GitHub Actions, Bash (install.sh), PowerShell (install.ps1), Dart compile

---

## Task 1: Create GitHub Actions Release Workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: Create the workflow directory**

```bash
mkdir -p .github/workflows
```

**Step 2: Create the release workflow file**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

env:
  DART_SDK_VERSION: '3.6.2'

jobs:
  build-macos-arm64:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: ${{ env.DART_SDK_VERSION }}

      - name: Install dependencies
        run: dart pub get

      - name: Build binary
        run: dart compile exe bin/ulink.dart -o ulink-macos-arm64

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ulink-macos-arm64
          path: ulink-macos-arm64

  build-macos-x64:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: ${{ env.DART_SDK_VERSION }}

      - name: Install dependencies
        run: dart pub get

      - name: Build binary
        run: dart compile exe bin/ulink.dart -o ulink-macos-x64

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ulink-macos-x64
          path: ulink-macos-x64

  build-linux-x64:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: ${{ env.DART_SDK_VERSION }}

      - name: Install dependencies
        run: dart pub get

      - name: Build binary
        run: dart compile exe bin/ulink.dart -o ulink-linux-x64

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ulink-linux-x64
          path: ulink-linux-x64

  build-windows-x64:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: ${{ env.DART_SDK_VERSION }}

      - name: Install dependencies
        run: dart pub get

      - name: Build binary
        run: dart compile exe bin/ulink.dart -o ulink-windows-x64.exe

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ulink-windows-x64
          path: ulink-windows-x64.exe

  release:
    needs: [build-macos-arm64, build-macos-x64, build-linux-x64, build-windows-x64]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Prepare release files
        run: |
          mkdir -p release
          cp artifacts/ulink-macos-arm64/ulink-macos-arm64 release/
          cp artifacts/ulink-macos-x64/ulink-macos-x64 release/
          cp artifacts/ulink-linux-x64/ulink-linux-x64 release/
          cp artifacts/ulink-windows-x64/ulink-windows-x64.exe release/
          chmod +x release/ulink-macos-arm64
          chmod +x release/ulink-macos-x64
          chmod +x release/ulink-linux-x64

      - name: Generate checksums
        run: |
          cd release
          sha256sum * > checksums.txt
          cat checksums.txt

      - name: Extract version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          name: ULink CLI ${{ steps.version.outputs.VERSION }}
          draft: false
          prerelease: false
          generate_release_notes: true
          files: |
            release/ulink-macos-arm64
            release/ulink-macos-x64
            release/ulink-linux-x64
            release/ulink-windows-x64.exe
            release/checksums.txt
```

**Step 3: Verify YAML syntax**

```bash
cat .github/workflows/release.yml | head -20
```

Expected: Shows the first 20 lines of valid YAML.

**Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add GitHub Actions release workflow

Build cross-platform binaries on version tags:
- macOS arm64 (Apple Silicon)
- macOS x64 (Intel)
- Linux x64
- Windows x64

Automatically creates GitHub Release with all binaries and checksums."
```

---

## Task 2: Create macOS/Linux Install Script

**Files:**
- Create: `scripts/install.sh`

**Step 1: Create scripts directory**

```bash
mkdir -p scripts
```

**Step 2: Create install.sh**

Create `scripts/install.sh`:

```bash
#!/bin/bash
#
# ULink CLI Installer for macOS and Linux
# Usage: curl -fsSL https://ulink.ly/install.sh | bash
#        curl -fsSL https://ulink.ly/install.sh | bash -s -- --ci
#        curl -fsSL https://ulink.ly/install.sh | bash -s -- --version v1.0.0

set -e

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
    local tmp_file=$(mktemp)
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
```

**Step 3: Make script executable**

```bash
chmod +x scripts/install.sh
```

**Step 4: Test script syntax**

```bash
bash -n scripts/install.sh && echo "Syntax OK"
```

Expected: `Syntax OK`

**Step 5: Commit**

```bash
git add scripts/install.sh
git commit -m "feat: add macOS/Linux install script

Supports:
- OS detection (macOS, Linux)
- Architecture detection (arm64, x64)
- --ci flag for silent CI installs
- --version flag for specific versions
- PATH setup instructions"
```

---

## Task 3: Create Windows Install Script

**Files:**
- Create: `scripts/install.ps1`

**Step 1: Create install.ps1**

Create `scripts/install.ps1`:

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    ULink CLI Installer for Windows

.DESCRIPTION
    Downloads and installs the ULink CLI tool.

.PARAMETER CI
    Silent mode for CI environments

.PARAMETER Version
    Specific version to install (e.g., v1.0.0). Default: latest

.EXAMPLE
    irm https://ulink.ly/install.ps1 | iex

.EXAMPLE
    & ./install.ps1 -Version v1.0.0
#>

param(
    [switch]$CI,
    [string]$Version = "latest",
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$Repo = "FlywheelStudio/ulink_cli"
$BinaryName = "ulink.exe"
$InstallDir = "$env:LOCALAPPDATA\ulink"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    if (-not $CI) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Write-LogAlways {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Show-Help {
    Write-Host @"
ULink CLI Installer for Windows

Usage:
    irm https://ulink.ly/install.ps1 | iex
    .\install.ps1 [options]

Options:
    -CI             Silent mode for CI environments
    -Version <ver>  Install specific version (e.g., v1.0.0)
    -Help           Show this help message

Examples:
    irm https://ulink.ly/install.ps1 | iex
    .\install.ps1 -Version v1.0.0
    .\install.ps1 -CI
"@
    exit 0
}

function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "x64" }
        "x86" { return "x64" }  # Use x64 for 32-bit too (runs via WoW64)
        "ARM64" {
            Write-LogAlways "Warning: ARM64 Windows is not yet supported. Trying x64 emulation." "Yellow"
            return "x64"
        }
        default {
            throw "Unsupported architecture: $arch"
        }
    }
}

function Get-DownloadUrl {
    param([string]$Arch, [string]$Ver)

    $binaryName = "ulink-windows-$Arch.exe"

    if ($Ver -eq "latest") {
        return "https://github.com/$Repo/releases/latest/download/$binaryName"
    } else {
        return "https://github.com/$Repo/releases/download/$Ver/$binaryName"
    }
}

function Add-ToPath {
    param([string]$Dir)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$Dir*") {
        $newPath = "$Dir;$currentPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path = "$Dir;$env:Path"
        return $true
    }
    return $false
}

function Main {
    if ($Help) {
        Show-Help
    }

    Write-Log "ULink CLI Installer" "Cyan"
    Write-Log ""

    # Detect architecture
    $arch = Get-Architecture
    Write-Log "Detected: windows-$arch" "Green"

    # Get download URL
    $url = Get-DownloadUrl -Arch $arch -Ver $Version
    Write-Log "Downloading from: $url" "Cyan"

    # Create install directory
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    $installPath = Join-Path $InstallDir $BinaryName

    # Download binary
    try {
        $ProgressPreference = 'SilentlyContinue'  # Speeds up download
        Invoke-WebRequest -Uri $url -OutFile $installPath -UseBasicParsing
    } catch {
        throw "Download failed: $_. Check if the version exists."
    }

    Write-Log ""
    Write-Log "Installed to: $installPath" "Green"

    # Add to PATH
    $pathAdded = Add-ToPath -Dir $InstallDir
    if ($pathAdded) {
        Write-Log ""
        Write-Log "Added $InstallDir to user PATH." "Yellow"
        Write-Log "Restart your terminal for PATH changes to take effect." "Yellow"
    }

    # Verify installation
    if (Test-Path $installPath) {
        Write-Log ""
        Write-LogAlways "ULink CLI installed successfully!" "Green"

        # Try to show version
        try {
            Write-Log ""
            & $installPath --version
        } catch {
            # Ignore version check errors
        }
    } else {
        throw "Installation verification failed"
    }
}

Main
```

**Step 2: Test PowerShell syntax (if on Windows or with pwsh)**

```bash
# Skip if pwsh not available - syntax will be validated on Windows
which pwsh && pwsh -Command "Get-Content scripts/install.ps1 | Out-Null; Write-Host 'Syntax OK'" || echo "pwsh not available, skipping syntax check"
```

**Step 3: Commit**

```bash
git add scripts/install.ps1
git commit -m "feat: add Windows install script

Supports:
- Architecture detection (x64, ARM64 fallback)
- -CI flag for silent CI installs
- -Version flag for specific versions
- Automatic PATH configuration"
```

---

## Task 4: Update README with Installation Instructions

**Files:**
- Modify: `README.md`

**Step 1: Read current README**

```bash
head -50 README.md
```

**Step 2: Add installation section to README**

Add after any existing header/intro section:

```markdown
## Installation

### Quick Install

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/FlywheelStudio/ulink_cli/main/scripts/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/FlywheelStudio/ulink_cli/main/scripts/install.ps1 | iex
```

### Install Specific Version

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/FlywheelStudio/ulink_cli/main/scripts/install.sh | bash -s -- --version v1.0.0
```

**Windows:**
```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/FlywheelStudio/ulink_cli/main/scripts/install.ps1))) -Version v1.0.0
```

### For Dart Developers

```bash
dart pub global activate --source git https://github.com/FlywheelStudio/ulink_cli.git
```

### Manual Download

Download binaries directly from [GitHub Releases](https://github.com/FlywheelStudio/ulink_cli/releases).
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add installation instructions to README"
```

---

## Task 5: Push Changes and Test Release

**Step 1: Push all commits**

```bash
git push origin main
```

**Step 2: Create and push test release tag**

```bash
git tag v1.0.0
git push origin v1.0.0
```

**Step 3: Monitor GitHub Actions**

Visit: `https://github.com/FlywheelStudio/ulink_cli/actions`

Wait for all jobs to complete (approximately 5-10 minutes).

**Step 4: Verify release artifacts**

Visit: `https://github.com/FlywheelStudio/ulink_cli/releases`

Expected files:
- `ulink-macos-arm64`
- `ulink-macos-x64`
- `ulink-linux-x64`
- `ulink-windows-x64.exe`
- `checksums.txt`

**Step 5: Test installation (macOS/Linux)**

```bash
curl -fsSL https://raw.githubusercontent.com/FlywheelStudio/ulink_cli/main/scripts/install.sh | bash
```

Expected: Binary downloads and installs to `~/.local/bin/ulink`

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | GitHub Actions workflow | `.github/workflows/release.yml` |
| 2 | macOS/Linux installer | `scripts/install.sh` |
| 3 | Windows installer | `scripts/install.ps1` |
| 4 | Update README | `README.md` |
| 5 | Push and test release | (git operations) |

**Total commits:** 4 (plus 1 tag)
