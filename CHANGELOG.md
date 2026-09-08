# Changelog

All notable changes to the ULink CLI will be documented in this file.

## [1.4.1] - 2026-09-08

### Fixed
- **`verify` now finds the project root from a subdirectory.** It previously
  inspected only the current directory, so running it from anywhere but the
  app root failed with a generic "Could not detect project type". It now walks
  up the tree to the nearest Flutter/iOS/Android/React Native root, and when no
  project is found up the tree the error names what it looked for
  (`pubspec.yaml`, `package.json`, `ios/`, or `android/`) and points at
  `--path`.

## [1.4.0] - 2026-09-07

### Added
- **`ulink api-keys` command** (`list` / `create` / `revoke`) to manage a
  project's client SDK API keys from the CLI. Project is resolved from
  `--project-id`, the saved directory config, or auto-selected when the account
  has exactly one project; the created key's secret is shown once.
- **`ulink verify --strict`** — exits `2` when the run was only a *partial*
  verification (a check that would actually verify deep linking, chiefly the
  dashboard cross-check, was not performed). Optional environment probes that
  simply could not run do not trip `--strict`.

### Fixed
- **`verify` no longer reports a bare green pass when checks were skipped.** A
  skipped dashboard cross-check is disclosed as `PARTIAL` / `NOT VERIFIED`;
  optional probe skips (no simulator/adb, managed-Expo with no native dirs) are
  shown separately and do not downgrade the verdict. The "not authenticated"
  wording is now gated on credentials, not on whether a project id resolved.
- **`verify` no longer pools URL schemes across platforms** — iOS and Android
  schemes are validated against their own platform config.
- **iOS bundle-id resolution is target-scoped** for multi-target Xcode projects
  (app + extension / watch / clip), so an extension or watch target can no
  longer masquerade as the main app.

## [1.3.1] - 2026-08-12

### Added
- **`ulink login --browser`** — explicit alias for the default browser-based
  login flow. Browser login is already the default, but the flag was never
  accepted, so `ulink login --browser` errored with "Could not find an option
  named browser". The `/auth/cli` page previously told users to run exactly that
  command on failure; the flag now parses as a no-op that selects the default
  flow, and the page copy points outdated CLIs at updating instead.

## [1.3.0] - 2026-06-28

Consolidation release: the Node `@ulink/cli` (FDL importer) work has been
ported into this canonical Dart CLI, so there is now a single `ulink` binary
and no command collisions. The deprecated Node `@ulink/cli` is retired.

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
- **`ulink verify <domain>` / `verify --domain`** — standalone Universal Links /
  App Links domain check (consolidated from the deprecated Node `@ulink/cli`):
  - Fetches and validates a domain's `apple-app-site-association` (AASA) and
    Android `assetlinks.json` directly, independent of any local project config.
  - Reports per-platform pass/fail with the parsed appIDs / package names, so a
    domain can be verified without a checked-out project.

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
