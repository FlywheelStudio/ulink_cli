# Changelog

All notable changes to the ULink CLI will be documented in this file.

## [1.0.0] - 2026-01-21

### Features

#### Authentication
- Browser-based OAuth login (recommended)
- Email/password login with `--password` flag
- API key authentication with `--api-key` flag
- Secure credential storage in `~/.ulink/config.json`
- `logout` command to clear stored credentials

#### Project Management
- `project set` command to link directories to ULink projects
- `project show` command to display linked project
- Interactive project selection from user's projects
- Direct project linking with `--slug` option
- Per-directory project configuration stored in `.ulink/config.json`

#### Verification
- Project type auto-detection (Flutter, iOS, Android)
- SDK package installation validation
- Local configuration file parsing (Info.plist, AndroidManifest.xml, entitlements)
- ULink API integration for project configuration
- Cross-reference validation between local and ULink configs
- Well-known file verification (AASA for iOS, Asset Links for Android)
- Runtime tests for iOS simulator and Android ADB
- Comprehensive verification report with pass/fail/warning status
- Onboarding status reporting to ULink dashboard

#### Interactive Fix Mode
- `fix` command for guided issue resolution
- Step-by-step instructions for common problems

#### Distribution
- Pre-built binaries for all major platforms:
  - macOS (Apple Silicon & Intel)
  - Linux (x64 & ARM64)
  - Windows (x64)
- One-line install scripts (`install.sh`, `install.ps1`)
- GitHub Releases integration
- Automated CI/CD release pipeline

### Supported Platforms
- Flutter projects (iOS + Android)
- iOS projects (Xcode)
- Android projects (Gradle)

### Requirements
- For iOS testing: Xcode with `xcrun simctl`
- For Android testing: Android SDK with `adb` in PATH

---

## [0.1.0] - 2026-01-15

### Features (Initial Development)
- Basic project type detection
- SDK package installation validation
- Local configuration file parsing
- ULink API integration (with manual API key)
- Basic verification report generation

### Notes
- This was an internal development release
- Required manual API key configuration
- No authentication system
