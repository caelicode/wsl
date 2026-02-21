#!/bin/sh
# CaeliCode WSL — Environment setup for all login shells.
# Sourced by /etc/profile on login. Ensures mise shims and tools are in PATH
# even when Docker ENV is lost after `docker export` → `wsl --import`.

# Mise (tool version manager)
export MISE_DATA_DIR="/opt/mise"
export MISE_CONFIG_DIR="/opt/mise/config"

# Add mise bin and shims to PATH if not already present
case ":${PATH}:" in
    *:/opt/mise/shims:*) ;;
    *) export PATH="/opt/mise/bin:/opt/mise/shims:${PATH}" ;;
esac

# Starship prompt config
export STARSHIP_CONFIG="/etc/caelicode/starship.toml"
