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
        echo "  ✓ ${name}: ${ver}"; ((PASS++))
    else
        echo "  ✗ ${name}: not found"; ((FAIL++))
    fi
}

echo "── SRE Profile Tests ──"

check_version "kubectl" "kubectl version --client --short"
check_version "helm" "helm version --short"
check_version "terraform" "terraform --version"
check_version "k9s" "k9s version --short"
check_version "argocd" "argocd version --client --short"
check_version "trivy" "trivy --version"

# Profile marker
PROFILE=$(cat /opt/caelicode/PROFILE 2>/dev/null || echo "unknown")
if [ "$PROFILE" = "sre" ]; then
    echo "  ✓ Profile marker: sre"; ((PASS++))
else
    echo "  ✗ Profile marker: expected 'sre', got '${PROFILE}'"; ((FAIL++))
fi

echo ""
echo "SRE Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
