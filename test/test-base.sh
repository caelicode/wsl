#!/usr/bin/env bash
# CaeliCode WSL — Base profile tests
set -euo pipefail

# shellcheck source=test/common.sh
source "$(dirname "$0")/common.sh"

echo "── Base Profile Tests ──"

# Core system tools
check_version "git" "git --version"
check_version "curl" "curl --version"
check_version "wget" "wget --version"
check_version "jq" "jq --version"
check_version "python3" "python3 --version"
check_version "mise" "mise --version"
check_version "zsh" "zsh --version"
check_version "tmux" "tmux -V"

# Modern CLI tools (via mise)
check_version "gh" "gh --version"
check_version "fzf" "fzf --version"
check_version "rg (ripgrep)" "rg --version"
check_version "fd" "fd --version"
check_version "bat" "bat --version"
check_version "eza" "eza --version"
check_version "delta" "delta --version"
check_version "starship" "starship --version"
check_version "direnv" "direnv --version"
check_version "zoxide" "zoxide --version"
check_version "yq" "yq --version"

# Starship (installed directly to /usr/local/bin, not via mise)
check "starship in /usr/local/bin" test -x /usr/local/bin/starship

# Oh My Zsh
check "oh-my-zsh installed" test -d /opt/oh-my-zsh
check "zsh-autosuggestions plugin" test -d /opt/oh-my-zsh/custom/plugins/zsh-autosuggestions
check "zsh-syntax-highlighting plugin" test -d /opt/oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# CaeliCode structure (versioned releases layout)
check "VERSION file exists" test -f /opt/caelicode/VERSION
check "PROFILE file exists" test -f /opt/caelicode/PROFILE
check "releases dir exists" test -d /opt/caelicode/releases
check "current symlink exists" test -L /opt/caelicode/current
check "current resolves" test -d /opt/caelicode/current/scripts
check "config.yaml exists" test -f /etc/caelicode/config.yaml
check "starship.toml exists" test -f /etc/caelicode/starship.toml
check "wsl.conf exists" test -f /etc/wsl.conf
check "health-check.sh exists" test -x /opt/caelicode/current/scripts/health-check.sh
check "caelicode-update exists" test -x /opt/caelicode/current/scripts/caelicode-update
check "caelicode-update in PATH" test -L /usr/local/bin/caelicode-update
check "caelicode-config in PATH" test -L /usr/local/bin/caelicode-config
check "runtime-init present" test -x /opt/caelicode/current/scripts/caelicode-runtime-init
check "update state dir exists" test -d /var/lib/caelicode

# Update-check timer (systemd)
check "systemd enabled in wsl.conf" grep -q "systemd = true" /etc/wsl.conf
check "update-check service installed" test -f /etc/systemd/system/caelicode-update-check.service
check "update-check timer installed" test -f /etc/systemd/system/caelicode-update-check.timer
check "update-check timer enabled" test -L /etc/systemd/system/timers.target.wants/caelicode-update-check.timer

# Shell config
check "bashrc in skel" test -f /etc/skel/.bashrc
check "bash_aliases in skel" test -f /etc/skel/.bash_aliases
check "zshrc in skel" test -f /etc/skel/.zshrc

# WSL config
check "appendWindowsPath disabled" grep -q "appendWindowsPath = false" /etc/wsl.conf
check "default user in wsl.conf" grep -q "default = caelicode" /etc/wsl.conf
check "caelicode user exists" getent passwd caelicode
check "caelicode user has zsh shell" grep -q "caelicode.*zsh" /etc/passwd
check "caelicode user has sudo" test -f /etc/sudoers.d/caelicode
check "caelicode user has .zshrc" test -f /home/caelicode/.zshrc
check "profile.d env script" test -f /etc/profile.d/00-caelicode-env.sh

# SSL/TLS
check "ca-certificates bundle exists" test -f /etc/ssl/certs/ca-certificates.crt

summarize "Results"
