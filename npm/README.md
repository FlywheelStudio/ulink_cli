# @ulinkly/cli

npm distribution of the **ULink CLI** — verify universal links & app links configuration for [ULink](https://ulink.ly) projects.

The CLI is a native binary (compiled from Dart). This package is a thin launcher: on first run it downloads the binary matching your platform from the [GitHub Releases](https://github.com/FlywheelStudio/ulink_cli/releases), verifies its checksum, caches it under `~/.ulink/npm/`, and runs it.

## Usage

Zero-install (recommended for one-off checks / CI):

```bash
npx @ulinkly/cli --help
npx @ulinkly/cli verify
```

Or install globally:

```bash
npm install -g @ulinkly/cli
ulink --version
```

## Supported platforms

| OS | Arch |
| --- | --- |
| macOS | arm64, x64 |
| Linux | x64 |
| Windows | x64 |

On other platforms, use the [install script or manual binaries](https://github.com/FlywheelStudio/ulink_cli/blob/main/INSTALL.md).

## Notes

- The npm version maps 1:1 to a CLI release tag (e.g. `1.2.0` → `v1.2.0`).
- The binary is cached per-version; upgrading the package re-downloads on next run.
- Set `ULINK_CLI_VERSION` (e.g. `v1.1.3`) to override the downloaded release.

## License

MIT
