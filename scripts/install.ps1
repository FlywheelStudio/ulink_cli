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
