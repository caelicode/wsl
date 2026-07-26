# CaeliCode WSL

[![Build & Release](https://github.com/caelicode/wsl/actions/workflows/build.yml/badge.svg)](https://github.com/caelicode/wsl/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Enterprise-grade WSL2 distro builder with **profile-based builds**, **pinned tool versions**, **update notifications**, **checksum-verified in-place updates with rollback**, **SSH agent forwarding**, and **proxy detection**.

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

This presents an interactive profile menu, downloads the latest release with live progress, verifies the checksum, and imports the distro (explicitly as WSL2) — all in one command.

Useful flags for direct invocation:

```powershell
.\install.ps1 -Profile sre                    # non-interactive
.\install.ps1 -Profile sre -Version v0.10.2   # pin a release
.\install.ps1 -Profile sre -Upgrade           # backup + reinstall
```

### Manual install

```powershell
# Download the tar.gz for your profile
Invoke-WebRequest -Uri https://github.com/caelicode/wsl/releases/latest/download/caelicode-wsl-sre.tar.gz -OutFile caelicode-wsl-sre.tar.gz

# Import into WSL
wsl --import caelicode-sre C:\wsl\caelicode caelicode-wsl-sre.tar.gz --version 2

# Launch
wsl -d caelicode-sre
```

You land in a zsh shell as the pre-created `caelicode` user (UID 1000,
passwordless sudo) — no boot-time setup required. Rename the user any
time with `sudo usermod -l yourname caelicode`.

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

### You get told when updates exist

A daily background check (systemd timer) caches the latest release
info locally; when something new ships, your login banner says so:

```
⬆ Update available: v0.10.2 → v0.11.0
  Run: caelicode-update
```

Shell startup never touches the network — the notice reads only the
local cache. Configure in `/etc/caelicode/config.yaml`
(`updates.check_enabled`, `updates.notify_motd`).

### In-place update

```bash
caelicode-update --check      # script-friendly: exits 0/10/20
caelicode-update --dry-run    # preview
caelicode-update              # apply
caelicode-update --rollback   # go back to the previous release
```

Updates are downloaded with SHA256 verification against the release
manifest, staged under `/opt/caelicode/releases/<version>/`, and
activated by an atomic symlink flip — a failed update leaves the
running release untouched, and the previous release stays on disk for
rollback. Tool versions are re-synced (including the `/opt/mise/bin`
symlinks the PATH actually uses). Your home directory and personal
settings are never touched.

### Full re-import (major upgrades)

Releases with OS-level changes are flagged in their manifest; the
updater refuses to half-apply them and points you at:

```bash
caelicode-update --full     # step-by-step guide, or:
```

```powershell
.\install.ps1 -Profile sre -Upgrade   # automatic backup, then reinstall
```

See [Updating](docs/updating.md) for the full design.

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

CaeliCode WSL ships with zsh as the default shell, powered by oh-my-zsh and starship. Plugins include zsh-autosuggestions and zsh-syntax-highlighting. Bash is fully configured as a fallback with starship integration, the same aliases, and the same SSL/proxy environment.

Smart aliases upgrade common tools transparently: `ls` uses eza, `cat` uses bat, `lt` shows an eza tree, `lg` opens lazygit — all with graceful fallback if a tool isn't available on your profile (the real `tree`, `python3`, etc. are never shadowed with incompatible flags).

### Configuration

`/etc/caelicode/config.yaml` is the single knob file — every key in it
is honored by the shipped scripts (read them with `caelicode-config`):

```yaml
branding:  motd_enabled, motd_text
proxy:     detect_enabled, merge_ca_certs
ssh:       agent_forwarding
dns:       watch_enabled, watch_interval
updates:   check_enabled, notify_motd, notify_windows_toast
```

Shell-visible changes apply on next login; service settings on next
boot. The file is never overwritten by updates.

### Team profiles & fleet policy

Layer team-specific tools on top of any profile without forking
(`caelicode-profile add <name> <https-url>`), pin or centrally manage
a fleet's updates via `/etc/caelicode/policy.yaml`, and serve releases
from your own fork. See [Enterprise & Team Features](docs/enterprise.md).

### DNS watcher (opt-in)

Set `dns.watch_enabled: true` and CaeliCode monitors DNS health,
re-pointing `/etc/resolv.conf` at the current Windows DNS servers when
resolution breaks (the classic VPN-connect failure) — with a
Cloudflare/Google fallback when Windows can't be queried.

### Devcontainer parity

The shipped [.devcontainer](.devcontainer/devcontainer.json) builds
the same Dockerfile (`dev-image` target), so VS Code devcontainers and
Codespaces match your WSL environment exactly.

### Prompt themes

CaeliCode ships with 5 Starship themes. Switch between them instantly:

```bash
# List available themes
caelicode-theme

# Switch to a theme
caelicode-theme gruvbox-rainbow

# Then reload your shell
exec $SHELL
```

Available themes: `default` (CaeliCode classic), `gruvbox-rainbow` (warm powerline), `tokyo-night` (cool blue/purple), `pastel-powerline` (soft gradient), and `jetpack` (minimalist with right-aligned info). All themes include CaeliCode-specific modules for Kubernetes, AWS, Azure, and GCP. In-place updates refresh whichever theme you're on (customized prompts are left alone).

### Terminal font (Nerd Font icons)

CaeliCode uses Starship prompt with Nerd Font icons for git status, directory indicators, and tool versions. The installer automatically installs the **MesloLGS NF** font and configures Windows Terminal and VS Code to use it (backing up your settings.json files first).

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

Bridges the Windows OpenSSH agent named pipe to a WSL Unix socket via `socat` + `npiperelay.exe`, so `ssh-add -l` and Git over SSH use your Windows-managed keys. The bridge starts automatically on the first shell of each boot (config: `ssh.agent_forwarding`); the socket is private to your user (mode 600). Requires [npiperelay](https://github.com/jstarks/npiperelay) on the Windows side — see [Troubleshooting](docs/troubleshooting.md#ssh-agent-bridge-not-working) for the one-time setup.

### Proxy detection

Reads the Windows WinHTTP proxy via `netsh.exe` on the first shell of each boot (config: `proxy.detect_enabled`) and exports `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` for all login shells. Optionally merges Windows root CA certificates into the Linux trust store (`proxy.merge_ca_certs`) for corporate TLS-inspection environments.

### VS Code integration

CaeliCode includes a built-in `code` wrapper that finds VS Code on your Windows install and launches it directly — no Windows PATH pollution needed (`appendWindowsPath` is deliberately set to `false` to avoid mise shim issues).

Open any WSL folder with:

```bash
code .
```

The wrapper probes standard install locations (user install, system install, Scoop) and caches the resolved path for fast subsequent launches. The VS Code [WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) auto-provisions the server component inside the distro.

**Requirements:** VS Code installed on Windows. Install the [WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) if it isn't bundled with your VS Code version.

**Troubleshooting:** If `code .` says "not found", clear the cached path with `rm -f ~/.cache/caelicode-vscode-path` and retry. See [Troubleshooting](docs/troubleshooting.md) for more details.

### Health check

```bash
caelicode-health
```

Validates DNS, tools (profile-aware), network connectivity, SSH agent status, and shows pending updates.

## Project Structure

```
├── Dockerfile          Multi-stage: base → sre/dev/data profiles
├── profiles/           Pinned tool versions (TOML, renovate-annotated)
├── config/             WSL, shell, starship, systemd configs
├── scripts/            Runtime scripts (update, health, theme, config,
│                       proxy, ssh-bridge, runtime-init, code)
├── test/               Profile test suites (run in CI on every build)
├── tools/              Windows-side helpers (backup)
├── install.ps1         One-line PowerShell installer
├── build.sh            Local build script
├── docs/               Documentation
└── .github/            CI/CD: build → test → promote-to-release
```

## Documentation

- [Getting Started](docs/getting-started.md) — Installation and first-launch walkthrough
- [Profiles](docs/profiles.md) — What each profile includes and when to use it
- [Updating](docs/updating.md) — Update notifications, in-place updates, rollback
- [Enterprise & Team](docs/enterprise.md) — Team profile layers, fleet policy, toasts, devcontainers
- [Troubleshooting](docs/troubleshooting.md) — Common issues and solutions

## License

[MIT](LICENSE)
