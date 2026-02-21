#!/usr/bin/env bash
# CaeliCode WSL — Data profile tests
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

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✓ ${name}"; ((PASS++))
    else
        echo "  ✗ ${name}"; ((FAIL++))
    fi
}

echo "── Data Profile Tests ──"

check_version "python3" "python3 --version"
check_version "uv" "uv --version"
check_version "psql" "psql --version"
check "dbt installed" command -v dbt

# Profile marker
PROFILE=$(cat /opt/caelicode/PROFILE 2>/dev/null || echo "unknown")
if [ "$PROFILE" = "data" ]; then
    echo "  ✓ Profile marker: data"; ((PASS++))
else
    echo "  ✗ Profile marker: expected 'data', got '${PROFILE}'"; ((FAIL++))
fi

echo ""
echo "Data Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
