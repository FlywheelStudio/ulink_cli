# ULink CLI

CLI tool for verifying and managing universal links (iOS) and app links (Android) configuration for ULink projects.

## AI-Assisted Setup (Recommended)

If you use Claude Code, Cursor, Codex, or another AI coding agent, the easiest way to use the ULink CLI is to let your AI agent drive it. Install the ULink onboarding skill in one command:

```bash
npx skills add https://ulink.ly
```

Then ask your agent to **"setup ulink"** — it'll install this CLI for you, run `ulink verify` against your project, and walk you through any failures. Works with 50+ AI agents via the [open agent-skills CLI](https://github.com/vercel-labs/skills). [Learn more →](https://docs.ulink.ly/getting-started/ai-setup)

## Installation

### npm (zero-install)

If you have Node.js, run the CLI with no install via [`@ulinkly/cli`](https://www.npmjs.com/package/@ulinkly/cli):

```bash
npx @ulinkly/cli --help
npx @ulinkly/cli verify
```

Or install it globally:

```bash
npm install -g @ulinkly/cli
ulink --version
```

> `@ulinkly/cli` is a thin launcher that downloads the matching native binary on first run and caches it. The npm version maps 1:1 to a CLI release (e.g. `1.2.0` → `v1.2.0`).

### Quick Install (script)

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

### `ulink import firebase`

Migrate your Firebase Dynamic Links (FDL) to ULink. Parses an FDL export,
recreates each link under your ULink domain, and verifies routing + attribution
parity for every link.

```bash
# Dry-run preview (default — never calls the API):
ulink import firebase --input fdl-export.json --domain acme.ulink.app

# Read a list of *.page.link URLs from stdin and print the manifest as JSON:
cat links.txt | ulink import firebase -i - -d acme.ulink.app --json

# Create the links for real (needs an API key):
ulink import firebase -i fdl-export.json -d acme.ulink.app --live --api-key $ULINK_API_KEY
```

Accepted inputs (auto-detected): a `DynamicLinkInfo` JSON object, an FDL
create-request wrapper, a batch `{ "links": [...] }`, a newline-delimited list
of FDL long-link URLs, or a CSV with a header row of your link inventory.
Use `-` for `--input` to read from stdin.

| Option | Short | Description |
|--------|-------|-------------|
| `--input` | `-i` | Path to your FDL export (`-` for stdin). **Required.** |
| `--domain` | `-d` | Your ULink domain for the new links. **Required.** |
| `--out` | `-o` | Output dir for the manifest + per-link JSON (default `./ulink-import`). |
| `--live` | | Create links via the ULink API (needs `--api-key`/`ULINK_API_KEY`). |
| `--api-key` | | ULink API key for `--live` (or set `ULINK_API_KEY`). |
| `--dry-run` | | Preview only; never calls the API (default until `--live`). |
| `--no-verify` | | Skip routing + attribution parity checks (on by default). |
| `--json` | | Print the manifest as JSON to stdout (for piping). |

Every run preserves attribution (UTM + iTunes Connect params, gclid) and
per-platform routing intent, forwarding them via the link's passthrough
parameters so they reach your app on open.

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
- **React Native / Expo**: Checks `package.json` for `@ulinkly/react-native` (and `app.json` for the Expo config plugin)
- **Android**: Checks `build.gradle` for `ly.ulink:ulink-sdk`
- **iOS**: Checks `Podfile` or `Package.swift` for `ULinkSDK`

### 2. Local Configuration Files
- **iOS**: `Info.plist`, entitlements file (Associated Domains, URL Types)
- **Android**: `AndroidManifest.xml` (intent filters, App Links)
- **Flutter**: Both iOS and Android configurations
- **React Native / Expo**: Both iOS and Android native config when present (bare RN or after `expo prebuild`); managed Expo projects are verified via the config plugin in `app.json`

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

# Verify a React Native / Expo project
cd ~/projects/my-rn-app
ulink project set
ulink verify -v   # run after `npx expo prebuild` for full native checks

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
- Issues: [GitHub Issues](https://github.com/FlywheelStudio/ulink_cli/issues)
