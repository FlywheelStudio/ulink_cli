# ULink CLI

CLI tool for verifying and managing universal links (iOS) and app links (Android) configuration for ULink projects.

## Installation

### Quick Install (Recommended)

**macOS / Linux:**
```bash
curl -fsSL https://ulink.ly/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://ulink.ly/install.ps1 | iex
```

### Install Specific Version

**macOS / Linux:**
```bash
curl -fsSL https://ulink.ly/install.sh | bash -s -- --version v1.0.0
```

**Windows:**
```powershell
& ([scriptblock]::Create((irm https://ulink.ly/install.ps1))) -Version v1.0.0
```

### For Dart Developers

```bash
dart pub global activate --source git https://github.com/mohn93/ulink_cli.git
```

### Manual Download

Download binaries directly from [GitHub Releases](https://github.com/mohn93/ulink_cli/releases).

## Quick Start

```bash
# 1. Login to your ULink account
ulink login

# 2. Navigate to your project directory
cd /path/to/your/app

# 3. Link to your ULink project
ulink project set

# 4. Verify your configuration
ulink verify
```

## Commands

### `ulink login`

Authenticate with your ULink account. Supports three authentication methods:

```bash
# Browser-based login (default, recommended)
ulink login

# Email/password login
ulink login --password

# API key login
ulink login --api-key
```

### `ulink logout`

Clear stored credentials:

```bash
ulink logout
```

### `ulink project set`

Link the current directory to a ULink project:

```bash
# Interactive project selection
ulink project set

# Set project by slug directly
ulink project set --slug my-project

# Set for a specific path
ulink project set --path ./my-app
```

### `ulink project show`

Show the currently linked project for a directory:

```bash
ulink project show

# For a specific path
ulink project show --path ./my-app
```

### `ulink verify`

Verify your project's deep link configuration:

```bash
# Verify current directory
ulink verify

# Verify specific path
ulink verify --path ./my-app

# Verbose output
ulink verify -v
```

### `ulink fix`

Interactive mode to fix configuration issues:

```bash
# Fix issues in current directory
ulink fix

# Fix issues in specific path
ulink fix --path ./my-app
```

### `ulink version`

Show version information:

```bash
ulink version
# or
ulink --version
```

## Global Options

| Option | Short | Description |
|--------|-------|-------------|
| `--verbose` | `-v` | Enable verbose output |
| `--interactive` | `-i` | Enable interactive mode |
| `--api-url` | | Override API base URL (for development) |
| `--help` | `-h` | Show help message |
| `--version` | `-V` | Show version information |

## What It Verifies

### 1. SDK Package Installation
- **Flutter**: Checks `pubspec.yaml` for `flutter_ulink_sdk`
- **Android**: Checks `build.gradle` for `ly.ulink:ulink-sdk`
- **iOS**: Checks `Podfile` or `Package.swift` for `ULinkSDK`

### 2. Local Configuration Files
- **iOS**: `Info.plist`, entitlements file (Associated Domains, URL Types)
- **Android**: `AndroidManifest.xml` (intent filters, App Links)
- **Flutter**: Both iOS and Android configurations

### 3. ULink Project Configuration
- Fetches project configuration from ULink API
- Cross-references with local configuration
- Validates bundle IDs, package names, and domains

### 4. Well-Known Files
- **iOS**: Tests AASA (Apple App Site Association) file accessibility and validity
- **Android**: Tests Asset Links JSON file accessibility and validity

### 5. Runtime Tests (Optional)
- **iOS**: Tests universal link opening in simulator
- **Android**: Checks app links verification status via ADB

## Requirements

- For iOS testing: Xcode with `xcrun simctl`
- For Android testing: Android SDK with `adb` in PATH

## Examples

```bash
# Full workflow for a Flutter project
ulink login
cd ~/projects/my-flutter-app
ulink project set --slug my-app
ulink verify -v

# Verify iOS-only project
cd ~/projects/my-ios-app
ulink project set
ulink verify --path ./ios

# Fix configuration issues interactively
ulink fix -v
```

## Troubleshooting

### "Not authenticated" error
Run `ulink login` to authenticate with your ULink account.

### "No project linked" error
Run `ulink project set` to link your directory to a ULink project.

### Verification failures
Run `ulink verify -v` for verbose output to see detailed error messages.

## Support

- Documentation: [https://ulink.ly/docs](https://ulink.ly/docs)
- Issues: [GitHub Issues](https://github.com/mohn93/ulink_cli/issues)
