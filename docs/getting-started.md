# Getting Started

## Prerequisites

- Windows 10 (version 2004+) or Windows 11
- WSL2 enabled (`wsl --install` in PowerShell as admin)
- ~2GB free disk space (varies by profile)

## Installation

### Option 1: One-line bootstrap (recommended)

Open PowerShell **as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/caelicode/wsl/main/install.ps1 | iex
```

The installer will:
- Check WSL2 prerequisites
- Present an interactive profile menu
- Download the latest release with progress
- Verify SHA256 checksum
- Import the distro into WSL

For non-interactive installs (e.g. scripted deployment):

```powershell
.\install.ps1 -Profile sre -InstallDir D:\wsl\caelicode -Force
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Profile` | `base`, `sre`, `dev`, or `data` | Interactive menu |
| `-InstallDir` | Where to store the WSL virtual disk | `%LOCALAPPDATA%\CaeliCode\wsl\<profile>` |
| `-DistroName` | WSL registration name | `caelicode-<profile>` |
| `-SkipWslCheck` | Skip WSL prerequisite checks | `$false` |
| `-Force` | Overwrite existing distro with same name | `$false` |

### Option 2: Manual download

1. Go to [Releases](https://github.com/caelicode/wsl/releases/latest)
2. Download the `.tar.gz` file for your profile
3. Import into WSL:

```powershell
wsl --import caelicode-sre C:\wsl\caelicode caelicode-wsl-sre.tar.gz
```

4. Launch:

```powershell
wsl -d caelicode-sre
```

### Option 2: Build locally

```bash
git clone https://github.com/caelicode/wsl.git
cd wsl
./build.sh --profile sre --tag v0.1.0
```

Then import the tar from `images/caelicode-wsl-sre.tar`.

## First Launch

On the first launch, CaeliCode automatically:

1. **Detects your Windows username** via `cmd.exe /c whoami`
2. **Creates a matching Linux user** with passwordless sudo
3. **Sets the default WSL user** (subsequent launches drop you in as your user, not root)
4. **Initializes DNS** from your Windows DNS settings, with Cloudflare/Google fallback
5. **Displays the CaeliCode MOTD** with your profile and version info

## Verify Installation

Run the built-in health check:

```bash
caelicode-health
```

This validates DNS resolution, tool availability (profile-aware), network connectivity, and SSH agent status.

## Setting as Default Distro

```powershell
wsl --set-default caelicode-sre
```

## Choosing a Profile

See [Profiles](profiles.md) for a detailed breakdown of each profile and which tools it includes.

| Profile | Use Case | Approx. Size |
|---------|----------|-------------|
| base | Minimal foundation, scripting | ~350MB |
| sre | Platform engineering, Kubernetes | ~800MB |
| dev | Software development | ~1.2GB |
| data | Data engineering, analytics | ~600MB |

## Uninstalling

```powershell
wsl --unregister caelicode-sre
```

This removes the distro and its virtual disk. Your Windows files are not affected.
