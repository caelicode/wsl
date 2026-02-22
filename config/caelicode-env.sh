#!/bin/sh
# CaeliCode WSL — Environment setup for all login shells.
# Sourced by /etc/profile on login. Ensures tools are in PATH
# even when Docker ENV is lost after `docker export` → `wsl --import`.

# Mise (tool version manager)
export MISE_DATA_DIR="/opt/mise"
export MISE_CONFIG_DIR="/opt/mise/config"

# Add mise bin to PATH if not already present.
# NOTE: /opt/mise/shims is NOT added — all tool binaries are
# symlinked into /opt/mise/bin/ at build time. Mise shims hang
# in WSL due to network timeouts during version resolution.
case ":${PATH}:" in
    *:/opt/mise/bin:*) ;;
    *) export PATH="/opt/mise/bin:${PATH}" ;;
esac

# Starship prompt config
export STARSHIP_CONFIG="/etc/caelicode/starship.toml"
