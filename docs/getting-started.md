# Getting Started

## Prerequisites

- Windows 10 (version 2004+) or Windows 11
- WSL2 enabled (`wsl --install` in PowerShell as admin)
- ~2GB free disk space (varies by profile)

## Installation

### Option 1: Download from GitHub Releases

1. Go to [Releases](https://github.com/caelicode/wsl/releases/latest)
2. Download the `.tar` file for your profile
3. Download the matching `.sha256` file and verify:

```powershell
certutil -hashfile caelicode-wsl-sre.tar SHA256
```

4. Import into WSL:

```powershell
wsl --import caelicode-sre C:\wsl\caelicode caelicode-wsl-sre.tar
```

5. Launch:

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
