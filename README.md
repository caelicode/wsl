# CaeliCode WSL

[![Build & Test](https://github.com/caelicode/wsl/actions/workflows/build.yml/badge.svg)](https://github.com/caelicode/wsl/actions/workflows/build.yml)
[![Release](https://github.com/caelicode/wsl/actions/workflows/release.yml/badge.svg)](https://github.com/caelicode/wsl/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Enterprise-grade WSL2 distro builder with **profile-based builds**, **pinned tool versions**, **dynamic DNS**, **SSH agent forwarding**, **proxy detection**, and **in-place updates**.

Built on Ubuntu 24.04 with systemd support.

## Profiles

| Tool | Base | SRE | Dev | Data |
|------|:----:|:---:|:---:|:----:|
| git, curl, jq, wget | ✓ | ✓ | ✓ | ✓ |
| mise (tool manager) | ✓ | ✓ | ✓ | ✓ |
| openssh-client | ✓ | ✓ | ✓ | ✓ |
| Python 3.12 | ✓ | ✓ | ✓ | ✓ |
| kubectl | | ✓ | | |
| helm | | ✓ | | |
| terraform | | ✓ | | |
| k9s | | ✓ | | |
| argocd-cli | | ✓ | | |
| trivy | | ✓ | | |
| Node.js | | | ✓ | |
| Go | | | ✓ | |
| Rust | | | ✓ | |
| Podman | | | ✓ | |
| uv | | | ✓ | ✓ |
| dbt-core | | | | ✓ |
| PostgreSQL client | | | | ✓ |

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

## Features

### Dynamic DNS resolution

A systemd timer polls Windows DNS every 5 seconds and rewrites `/etc/resolv.conf` when changes are detected. Survives VPN connect/disconnect without manual intervention.

### SSH agent forwarding

Bridges the Windows OpenSSH agent named pipe to a WSL Unix socket via `socat`, so `ssh-add -l` and Git over SSH work transparently.

### Proxy detection

Reads Windows proxy settings via `netsh.exe` and merges Windows root CA certificates into the Linux trust store. Handles corporate MITM proxy environments.

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

### Configurable branding

Edit `/etc/caelicode/config.yaml` to customize the MOTD, PS1 prompt features, colors, and behavior. Changes take effect on next login — no re-import needed.

## Project Structure

```
├── Dockerfile          Multi-stage: base → sre/dev/data profiles
├── profiles/           Pinned tool versions (TOML)
├── config/             WSL, shell, systemd configs
├── scripts/            Runtime scripts (DNS, SSH, proxy, update)
├── test/               Profile-specific test suites
├── build.sh            Local build script
├── docs/               Documentation
└── .github/workflows/  CI/CD (build matrix + release)
```

## Documentation

- [Getting Started](docs/getting-started.md) — Installation and first-launch walkthrough
- [Profiles](docs/profiles.md) — What each profile includes and when to use it
- [Updating](docs/updating.md) — How in-place updates work
- [Troubleshooting](docs/troubleshooting.md) — Common issues and solutions

## License

[MIT](LICENSE)
