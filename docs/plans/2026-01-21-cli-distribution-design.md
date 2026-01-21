# ULink CLI Distribution Design

**Date:** 2026-01-21
**Status:** Approved

## Overview

This document outlines the distribution strategy for the ULink CLI tool across macOS, Linux, and Windows platforms. The goal is minimal maintenance with automated releases.

## Distribution Channels

| Platform | Primary Method | Command |
|----------|---------------|---------|
| macOS | Install script | `curl -fsSL https://ulink.ly/install.sh \| bash` |
| Linux | Install script | `curl -fsSL https://ulink.ly/install.sh \| bash` |
| Windows | PowerShell script | `irm https://ulink.ly/install.ps1 \| iex` |
| Dart devs | pub global | `dart pub global activate ulink` |
| Direct | GitHub Releases | Manual download |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Release Process                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Developer                GitHub Actions              Users    │
│   ─────────               ──────────────              ─────     │
│                                                                 │
│   git tag v1.0.0  ───►  Build Matrix:                          │
│   git push              ├─ macos-latest (arm64, x64)           │
│                         ├─ ubuntu-latest (x64)                  │
│                         └─ windows-latest (x64)                 │
│                                   │                             │
│                                   ▼                             │
│                         Create GitHub Release                   │
│                         with all binaries                       │
│                                   │                             │
│                                   ▼                             │
│                         ┌─────────────────┐                     │
│                         │ GitHub Releases │ ◄── install.sh      │
│                         │  - ulink-macos-arm64                  │
│                         │  - ulink-macos-x64   ◄── install.ps1  │
│                         │  - ulink-linux-x64                    │
│                         │  - ulink-windows-x64.exe              │
│                         │  - checksums.txt                      │
│                         └─────────────────┘                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. GitHub Actions Workflow (`.github/workflows/release.yml`)

Triggered on version tags (`v*`). Builds native binaries for all platforms.

**Build Matrix:**
- `macos-latest` - Builds arm64 binary (Apple Silicon)
- `macos-13` - Builds x64 binary (Intel Mac)
- `ubuntu-latest` - Builds x64 binary
- `windows-latest` - Builds x64 binary

**Steps per job:**
1. Checkout code
2. Setup Dart SDK
3. Run `dart compile exe bin/ulink.dart -o ulink`
4. Upload artifact

**Final job:**
1. Download all artifacts
2. Generate SHA256 checksums
3. Create GitHub Release with all binaries

### 2. Install Script - macOS/Linux (`scripts/install.sh`)

Bash script that:
1. Detects OS (Darwin/Linux) and architecture (arm64/x86_64)
2. Downloads correct binary from GitHub Releases
3. Installs to `~/.local/bin/ulink`
4. Adds `~/.local/bin` to PATH if needed
5. Verifies installation

**Flags:**
- `--ci` - Silent mode, no prompts (for CI environments)
- `--version <ver>` - Install specific version (default: latest)

### 3. Install Script - Windows (`scripts/install.ps1`)

PowerShell script that:
1. Detects architecture
2. Downloads `.exe` from GitHub Releases
3. Installs to `%LOCALAPPDATA%\ulink\ulink.exe`
4. Adds to user PATH
5. Verifies installation

**Flags:**
- `-CI` - Silent mode
- `-Version <ver>` - Install specific version

### 4. Version Management

Version is managed in `lib/config/version.dart`:
```dart
class Version {
  static const String version = '1.0.0';
  static const String buildNumber = '37';
  static const String buildDate = '2026-01-21';
}
```

The `build.sh` script handles version bumping locally. For releases:
1. Update version manually in `version.dart`
2. Commit: `git commit -m "Release v1.0.1"`
3. Tag: `git tag v1.0.1`
4. Push: `git push origin main --tags`

## File Structure

```
ulink_cli/
├── .github/
│   └── workflows/
│       └── release.yml          # CI/CD workflow
├── scripts/
│   ├── install.sh               # macOS/Linux installer
│   └── install.ps1              # Windows installer
├── docs/
│   └── plans/
│       └── 2026-01-21-cli-distribution-design.md
├── bin/
│   └── ulink.dart               # Entry point
├── lib/
│   └── config/
│       └── version.dart         # Version management
└── ...
```

## Release Checklist

1. [ ] Update version in `lib/config/version.dart`
2. [ ] Update `CHANGELOG.md`
3. [ ] Commit changes
4. [ ] Create and push tag: `git tag v1.x.x && git push origin main --tags`
5. [ ] Verify GitHub Actions builds complete
6. [ ] Verify release artifacts on GitHub Releases
7. [ ] Test installation on each platform

## Future Enhancements (Optional)

If user demand warrants it:
- **Homebrew tap** (`homebrew-ulink` repo) - Formula auto-updated by CI
- **Scoop bucket** (`scoop-ulink` repo) - JSON manifest auto-updated by CI
- **npm wrapper** - For Node.js developers
- **Docker image** - For containerized environments

## Implementation Tasks

1. Create `.github/workflows/release.yml`
2. Create `scripts/install.sh`
3. Create `scripts/install.ps1`
4. Set up `ulink.ly/install.sh` redirect (or host script)
5. Test release workflow with `v1.0.0` tag
