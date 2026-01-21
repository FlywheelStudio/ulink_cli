# Installing ULink CLI

## Quick Install (Recommended)

### macOS / Linux

```bash
curl -fsSL https://ulink.ly/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://ulink.ly/install.ps1 | iex
```

The install script will:
- Download the latest release for your platform
- Install to `~/.ulink/bin`
- Add the binary to your PATH

## Install Specific Version

### macOS / Linux

```bash
curl -fsSL https://ulink.ly/install.sh | bash -s -- --version v1.0.0
```

### Windows

```powershell
& ([scriptblock]::Create((irm https://ulink.ly/install.ps1))) -Version v1.0.0
```

## CI/CD Installation

For CI environments, use the `--ci` flag to skip interactive prompts:

```bash
curl -fsSL https://ulink.ly/install.sh | bash -s -- --ci
```

## Manual Installation

### Download from GitHub Releases

1. Go to [GitHub Releases](https://github.com/mohn93/ulink_cli/releases)
2. Download the appropriate binary for your platform:
   - `ulink-macos-arm64` - macOS Apple Silicon
   - `ulink-macos-x64` - macOS Intel
   - `ulink-linux-x64` - Linux x64
   - `ulink-linux-arm64` - Linux ARM64
   - `ulink-windows-x64.exe` - Windows x64
3. Make it executable (macOS/Linux):
   ```bash
   chmod +x ulink-*
   ```
4. Move to a directory in your PATH:
   ```bash
   sudo mv ulink-* /usr/local/bin/ulink
   ```

### For Dart Developers

If you have Dart SDK installed:

```bash
dart pub global activate --source git https://github.com/mohn93/ulink_cli.git
```

## Verify Installation

After installation, verify it works:

```bash
ulink --version
```

You should see version information like:
```
ULink CLI Version: 1.0.0
Build Number: 37
Build Date: 2026-01-21
```

## Updating

To update to the latest version, simply run the install script again:

```bash
# macOS / Linux
curl -fsSL https://ulink.ly/install.sh | bash

# Windows
irm https://ulink.ly/install.ps1 | iex
```

## Uninstall

### If installed via script

```bash
rm -rf ~/.ulink
```

Then remove the PATH entry from your shell config (`~/.zshrc`, `~/.bashrc`, etc.).

### If installed manually

```bash
sudo rm /usr/local/bin/ulink
```

### If installed via Dart

```bash
dart pub global deactivate ulink_cli
```
