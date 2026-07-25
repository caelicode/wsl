# Getting Started

## Prerequisites

- Windows 10 (version 2004+) or Windows 11, **x86_64** (ARM64 devices
  are not yet supported — the installer checks and will tell you)
- WSL2 enabled (`wsl --install --no-distribution` in PowerShell as admin)
- Free disk space for your profile (see table below)

## Installation

### Option 1: One-line bootstrap (recommended)

Open PowerShell **as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/caelicode/wsl/main/install.ps1 | iex
```

The installer will:
- Check WSL2 prerequisites and CPU architecture
- Present an interactive profile menu
- Download the release with live progress
- Verify the SHA256 checksum
- Import the distro into WSL (as WSL2, explicitly)

For non-interactive installs (e.g. scripted deployment):

```powershell
.\install.ps1 -Profile sre -InstallDir D:\wsl\caelicode -Force
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Profile` | `base`, `sre`, `dev`, or `data` | Interactive menu |
| `-InstallDir` | Where to store the WSL virtual disk | `%LOCALAPPDATA%\CaeliCode\wsl\<profile>` |
| `-DistroName` | WSL registration name | `caelicode-<profile>` |
| `-Version` | Install a specific release tag (e.g. `v0.10.2`) | Latest release |
| `-Upgrade` | Back up the existing distro, then reinstall | `$false` |
| `-SkipWslCheck` | Skip WSL prerequisite checks | `$false` |
| `-Force` | Overwrite existing distro **without** a backup | `$false` |

### Option 2: Manual download

1. Go to [Releases](https://github.com/caelicode/wsl/releases/latest)
2. Download the `.tar.gz` file for your profile (verify it against the
   matching `.sha256` asset)
3. Import into WSL:

```powershell
wsl --import caelicode-sre C:\wsl\caelicode caelicode-wsl-sre.tar.gz --version 2
```

4. Launch:

```powershell
wsl -d caelicode-sre
```

### Option 3: Build locally

```bash
git clone https://github.com/caelicode/wsl.git
cd wsl
./build.sh --profile sre --tag v0.1.0
```

Then import the tar from `images/caelicode-wsl-sre.tar`.

## First Launch

The distro ships ready to use — no boot-time setup runs:

1. You land in a zsh shell as the pre-created **`caelicode`** user
   (UID 1000, passwordless sudo). Rename it any time:
   `sudo usermod -l yourname caelicode`
2. The CaeliCode banner shows your profile and version.
3. On the first shell of each boot, CaeliCode starts its runtime
   services in the background: Windows proxy detection and the SSH
   agent bridge (both configurable in `/etc/caelicode/config.yaml`).
4. A daily background check notifies you at login when a new release
   is available.

## Verify Installation

Run the built-in health check:

```bash
caelicode-health
```

This validates DNS resolution, tool availability (profile-aware),
network connectivity, SSH agent status, and update state.

## Setting as Default Distro

```powershell
wsl --set-default caelicode-sre
```

## Choosing a Profile

See [Profiles](profiles.md) for a detailed breakdown of each profile
and which tools it includes.

| Profile | Use Case | Download | On disk |
|---------|----------|----------|---------|
| base | Minimal foundation, scripting | ~0.4GB | ~1.1GB |
| sre | Platform engineering, Kubernetes | ~1.2GB | ~3.5GB |
| dev | Software development | ~1.5GB | ~4.5GB |
| data | Data engineering, analytics | ~0.6GB | ~1.8GB |

(Sizes are approximate and drift as pinned tools update.)

## Uninstalling

```powershell
wsl --unregister caelicode-sre
```

This removes the distro and its virtual disk. Your Windows files are
not affected. See the [README](../README.md#uninstall) for removing
the install directory too.
