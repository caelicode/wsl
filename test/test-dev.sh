#!/usr/bin/env bash
# CaeliCode WSL — Dev profile tests
set -euo pipefail

# Run base tests first
bash "$(dirname "$0")/test-base.sh" || exit 1

# shellcheck source=test/common.sh
source "$(dirname "$0")/common.sh"

echo "── Dev Profile Tests ──"

# Language runtimes
check_version "node" "node --version"
check_version "go" "go version"
check_version "rustc" "rustc --version"
check_version "java" "java --version"
check_version "bun" "bun --version"
check_version "uv" "uv --version"

# Container tools
check_version "podman" "podman --version"

# Developer tools
check_version "lazygit" "lazygit --version"
check_version "shellcheck" "shellcheck --version"
check_version "hadolint" "hadolint --version"

# Profile marker
check "profile marker is dev" grep -qx "dev" /opt/caelicode/PROFILE

summarize "Dev Results"
