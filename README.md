# CaeliCode WSL

[![Build & Release](https://github.com/caelicode/wsl/actions/workflows/build.yml/badge.svg)](https://github.com/caelicode/wsl/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Enterprise-grade WSL2 distro builder with **profile-based builds**, **pinned tool versions**, **SSH agent forwarding**, **proxy detection**, and **in-place updates**.

Built on Ubuntu 24.04.

## Profiles

### Shared foundation (all profiles)

| Category | Tools |
|----------|-------|
| **Shell** | zsh (default) + oh-my-zsh, bash, starship prompt, tmux |
| **CLI essentials** | git, curl, jq, wget, vim, nano, htop, tree, zip/unzip |
| **Modern CLI** | gh, fzf, ripgrep (rg), fd, bat, eza, delta, direnv, zoxide, yq |
| **Runtime** | Python 3.12, mise (tool version manager) |
| **Network** | openssh-client, socat, dnsutils, netcat |

### Profile-specific tools

| Tool | SRE | Dev | Data |
|------|:---:|:---:|:----:|
| kubectl, helm, k9s | ✓ | | |
| argocd-cli, flux | ✓ | | |
| kubectx, kubens, kustomize, stern | ✓ | | |
| terraform, packer, vault | ✓ | | |
| AWS CLI, Azure CLI, Google Cloud SDK | ✓ | | |
| eksctl | ✓ | | |
| trivy | ✓ | | |
| Node.js, Go, Rust, Java (Temurin 21), Bun | | ✓ | |
| uv (Python package manager) | | ✓ | ✓ |
| Podman | | ✓ | |
| lazygit, shellcheck, hadolint | | ✓ | |
| dbt-core, DuckDB, JupyterLab | | | ✓ |
| PostgreSQL, Redis, SQLite clients | | | ✓ |

## Quick Start

### One-line install (recommended)

Open PowerShell **as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/caelicode/wsl/main/install.ps1 | iex
```

This presents an interactive profile menu, downloads the latest release, verifies the checksum, and imports the distro — all in one command.

To install a specific profile non-interactively:

```powershell
.\install.ps1 -Profile sre
```

### Manual install

```powershell
# Download the tar.gz for your profile
Invoke-WebRequest -Uri https://github.com/caelicode/wsl/releases/latest/download/caelicode-wsl-sre.tar.gz -OutFile caelicode-wsl-sre.tar.gz

# Import into WSL
wsl --import caelicode-sre C:\wsl\caelicode caelicode-wsl-sre.tar.gz

# Launch
wsl -d caelicode-sre
```

On first launch, the distro automatically detects your Windows username, creates a matching Linux user with passwordless sudo, and configures DNS.

### Build locally

```bash
git clone https://github.com/caelicode/wsl.git
cd wsl

# Build a single profile
./build.sh --profile sre --tag v0.1.0

# Build all profiles
./build.sh --all --tag v0.1.0

# Import the tar into WSL
wsl --import caelicode-sre C:\wsl\caelicode images/caelicode-wsl-sre.tar
```

## Updating

### In-place update (recommended)

Most updates — new tool versions, script fixes, config improvements — can be applied without reimporting:

```bash
# Check what's available
caelicode-update --dry-run

# Apply the update
caelicode-update
```

This downloads the latest release from GitHub, updates scripts, configs, and tool version manifests, then runs `mise install` to upgrade your tools. Your home directory and personal settings are never touched.

### Full re-import (major upgrades)

Some releases include new system packages, shell changes, or OS-level updates that can't be applied in-place. When that's the case, the release notes will say so. Run:

```bash
caelicode-update --full
```

This prints a step-by-step guide to back up your data, unregister the old distro, re-import the new one, and restore your files.

## Uninstall

To completely remove a CaeliCode WSL distro:

```powershell
# 1. Unregister the distro (this deletes all data inside it)
wsl --unregister caelicode-sre

# 2. Remove the install directory
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\CaeliCode\wsl\sre"
```

Replace `caelicode-sre` and `sre` with your profile name (`base`, `dev`, or `data`). If you used a custom install directory, adjust the path accordingly.

To list all installed WSL distros and confirm removal:

```powershell
wsl --list --verbose
```

## Features

### Shell experience

CaeliCode WSL ships with zsh as the default shell, powered by oh-my-zsh and starship. Plugins include zsh-autosuggestions and zsh-syntax-highlighting. Bash is fully configured as a fallback with starship integration and the same aliases.

Smart aliases upgrade common tools transparently: `ls` uses eza, `cat` uses bat, `lg` opens lazygit — all with graceful fallback if a tool isn't available on your profile.

Edit `/etc/caelicode/starship.toml` to customize the prompt, or `/etc/caelicode/config.yaml` for MOTD and branding. Changes take effect on next login — no re-import needed.

### Terminal font (Nerd Font icons)

CaeliCode uses Starship prompt with Nerd Font icons for git status, directory indicators, and tool versions. The installer automatically installs the **MesloLGS NF** font and configures Windows Terminal and VS Code to use it.

If icons display as `?` or blank rectangles, the font wasn't applied to your terminal. Set it manually:

**Windows Terminal:** Settings (`Ctrl+,`) → Defaults → Appearance → Font face → `MesloLGS NF`

**VS Code integrated terminal:** Settings (`Ctrl+,`) → search `terminal.integrated.fontFamily` → set to `MesloLGS NF`

Or add to your VS Code `settings.json` directly:

```json
"terminal.integrated.fontFamily": "MesloLGS NF"
```

If the font is missing entirely, download it from the [powerlevel10k font repository](https://github.com/romkatv/powerlevel10k#fonts) and install all four variants (Regular, Bold, Italic, Bold Italic).

### DNS resolution

WSL auto-generates `/etc/resolv.conf` on each boot with the correct DNS servers from your Windows network configuration. If DNS breaks (e.g., after VPN connect/disconnect), restart WSL with `wsl --shutdown` and relaunch.

### SSH agent forwarding

Bridges the Windows OpenSSH agent named pipe to a WSL Unix socket via `socat`, so `ssh-add -l` and Git over SSH work transparently.

### Proxy detection

Reads Windows proxy settings via `netsh.exe` and merges Windows root CA certificates into the Linux trust store. Handles corporate MITM proxy environments.

### VS Code integration

CaeliCode includes a built-in `code` wrapper that finds VS Code on your Windows install and launches it directly — no Windows PATH pollution needed (`appendWindowsPath` is deliberately set to `false` to avoid mise shim issues).

Open any WSL folder with:

```bash
code .
```

The wrapper probes standard install locations (user install, system install, Scoop) and caches the resolved path for fast subsequent launches. The VS Code [WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) auto-provisions the server component inside the distro.

**Requirements:** VS Code installed on Windows. Install the [WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) if it isn't bundled with your VS Code version.

### In-place updates

```bash
# Check for updates
caelicode-update --dry-run

# Update scripts and config (never touches $HOME)
caelicode-update
```

### Health check

```bash
caelicode-health
```

Validates DNS, tools (profile-aware), network connectivity, and SSH agent status.

## Project Structure

```
├── Dockerfile          Multi-stage: base → sre/dev/data profiles
├── profiles/           Pinned tool versions (TOML)
├── config/             WSL, shell, starship configs
├── scripts/            Runtime scripts (health check, update)
├── test/               Profile-specific test suites
├── install.ps1         One-line PowerShell installer
├── build.sh            Local build script
├── docs/               Documentation
└── .github/workflows/  CI/CD (build matrix + semantic-release)
```

## Documentation

- [Getting Started](docs/getting-started.md) — Installation and first-launch walkthrough
- [Profiles](docs/profiles.md) — What each profile includes and when to use it
- [Updating](docs/updating.md) — How in-place updates work
- [Troubleshooting](docs/troubleshooting.md) — Common issues and solutions

## License

[MIT](LICENSE)
