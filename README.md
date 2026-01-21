# ULink CLI

CLI tool for verifying universal links (iOS) and app links (Android) configuration for ULink projects.

## Installation

### Quick Install

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
dart pub global activate --source git https://github.com/FlywheelStudio/ulink_cli.git
```

### Manual Download

Download binaries directly from [GitHub Releases](https://github.com/FlywheelStudio/ulink_cli/releases).

## Usage

### Verify Configuration

```bash
ulink verify --project-id <project-id> --api-key <api-key> [--path <project-path>]
```

### Interactive Fix Mode

```bash
ulink fix --project-id <project-id> --api-key <api-key> [--path <project-path>]
```

## Options

- `--project-id, -p`: ULink project ID
- `--api-key, -k`: ULink API key
- `--base-url, -u`: ULink API base URL (default: https://api.ulink.ly)
- `--path, -p`: Project path (default: current directory)
- `--verbose, -v`: Verbose output
- `--interactive, -i`: Interactive mode

## What It Checks

1. **SDK Package Installation**
   - Flutter: Checks `pubspec.yaml` for `flutter_ulink_sdk`
   - Android: Checks `build.gradle` for `ly.ulink:ulink-sdk`
   - iOS: Checks `Podfile` or `Package.swift` for `ULinkSDK`

2. **Local Configuration Files**
   - iOS: `Info.plist`, entitlements file
   - Android: `AndroidManifest.xml`
   - Flutter: Both iOS and Android configurations

3. **ULink Project Configuration**
   - Fetches project configuration from ULink API
   - Cross-references with local configuration

4. **Well-Known Files**
   - Tests AASA file accessibility and validity (iOS)
   - Tests Asset Links JSON file accessibility and validity (Android)

5. **Runtime Tests** (optional)
   - iOS: Tests universal link opening in simulator
   - Android: Checks app links verification status via ADB

## Requirements

- Dart SDK 3.6.2 or higher
- For iOS testing: Xcode with `xcrun simctl`
- For Android testing: Android SDK with `adb` in PATH

## Examples

```bash
# Verify Flutter project
ulink verify -p my-project-id -k my-api-key

# Verify iOS project
ulink verify -p my-project-id -k my-api-key --path ./ios

# Verify with verbose output
ulink verify -p my-project-id -k my-api-key -v
```
