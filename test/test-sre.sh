#!/usr/bin/env bash
# CaeliCode WSL — SRE profile tests
set -euo pipefail

# Run base tests first
bash "$(dirname "$0")/test-base.sh" || exit 1

PASS=0; FAIL=0

check_version() {
    local name="$1" cmd="$2"
    local ver
    ver=$($cmd 2>&1 | head -1) || true
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

echo "── SRE Profile Tests ──"

# Kubernetes & orchestration
check_version "kubectl" "kubectl version --client --short"
check_version "helm" "helm version --short"
check_version "k9s" "k9s version --short"
check_version "argocd" "argocd version --client --short"
check_version "kubectx" "kubectx --version"
check_version "kustomize" "kustomize version"
check_version "stern" "stern --version"
check_version "flux" "flux --version"

# Infrastructure as Code
check_version "terraform" "terraform --version"
check_version "packer" "packer --version"
check_version "vault" "vault --version"

# Cloud CLIs
check_version "aws" "aws --version"
check_version "eksctl" "eksctl version"
check_version "az (Azure)" "az --version"
check_version "gcloud" "gcloud --version"

# Security
check_version "trivy" "trivy --version"

# Profile marker
PROFILE=$(cat /opt/caelicode/PROFILE 2>/dev/null || echo "unknown")
if [ "$PROFILE" = "sre" ]; then
    echo "  ✓ Profile marker: sre"; PASS=$((PASS + 1))
else
    echo "  ✗ Profile marker: expected 'sre', got '${PROFILE}'"; FAIL=$((FAIL + 1))
fi

echo ""
echo "SRE Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
