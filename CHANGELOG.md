# Changelog

All notable changes to the ULink CLI will be documented in this file.

## [Unreleased]

### Added
- **`ulink import firebase`** — migrate Firebase Dynamic Links to ULink
  (consolidated from the deprecated Node `@ulink/cli`, re-implemented in Dart):
  - Parses FDL exports in every common shape: `DynamicLinkInfo` JSON objects /
    create-request wrappers, batch `{ "links": [...] }`, newline-delimited FDL
    long-link URLs, and CSV link inventories (with header-alias detection).
  - Maps each link losslessly to a ULink definition, preserving per-platform
    routing and **attribution** (UTM + iTunes Connect params, gclid) and
    forwarding them via passthrough parameters.
  - Dry-run by default (no network); `--live --api-key` creates links via
    `POST /sdk/links`. Built-in static parity verification plus a live
    routing-parity probe; writes a manifest + per-link JSON artifacts.
- **`ulink resolve <url>`** — standalone per-platform short-URL resolution
  (consolidated from the deprecated Node `@ulink/cli`, re-implemented in Dart):
  - Reads back how a live ULink short URL routes on iOS / iPad / Android /
    desktop via `GET /sdk/resolve`, plus the in-app deep link and forwarded
    attribution parameters. Read-only — never creates or mutates anything.
  - Human-readable output by default; `--json` for machine-readable output.
    Optional `--api-key`/`ULINK_API_KEY` surfaces owner-only attribution.
  - Distinguishes a genuine 404 (link not found) from an unreachable edge;
    exit codes `0` resolved / `1` not-found-or-unreachable / `2` bad usage.

## [1.2.0] - 2026-06-22

### Added
- **React Native / Expo project support** in `ulink verify`:
  - Auto-detects React Native / Expo projects (`package.json` with `react-native` / `expo`)
  - Validates the `@ulinkly/react-native` package is installed
  - Checks for the Expo config plugin in `app.json`
  - Verifies iOS + Android native config when present (bare RN or after `expo prebuild`); reports plugin-managed config for managed Expo projects

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
