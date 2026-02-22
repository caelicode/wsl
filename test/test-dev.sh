#!/usr/bin/env bash
# CaeliCode WSL — Dev profile tests
set -euo pipefail

# Run base tests first
bash "$(dirname "$0")/test-base.sh" || exit 1

PASS=0; FAIL=0

check_version() {
    local name="$1" cmd="$2"
    local ver
    ver="$($cmd 2>&1 | head -1)" || true
    if [ -n "$ver" ]; then
        echo "  ✓ ${name}: ${ver}"; PASS=$((PASS + 1))
    else
        echo "  ✗ ${name}: not found"; FAIL=$((FAIL + 1))
    fi
}

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✓ ${name}"; PASS=$((PASS + 1))
    else
        echo "  ✗ ${name}"; FAIL=$((FAIL + 1))
    fi
}

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
PROFILE="$(cat /opt/caelicode/PROFILE 2>/dev/null || echo "unknown")"
if [ "$PROFILE" = "dev" ]; then
    echo "  ✓ Profile marker: dev"; PASS=$((PASS + 1))
else
    echo "  ✗ Profile marker: expected 'dev', got '${PROFILE}'"; FAIL=$((FAIL + 1))
fi

echo ""
echo "Dev Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
