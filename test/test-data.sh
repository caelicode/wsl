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

echo "── Data Profile Tests ──"

# Core data tools
check_version "python3" "python3 --version"
check_version "uv" "uv --version"
check_version "psql" "psql --version"
check_version "sqlite3" "sqlite3 --version"
check_version "duckdb" "duckdb --version"
check "dbt installed" command -v dbt
check "jupyter installed" command -v jupyter

# Redis client
check_version "redis-cli" "redis-cli --version"

# Profile marker
PROFILE=$(cat /opt/caelicode/PROFILE 2>/dev/null || echo "unknown")
if [ "$PROFILE" = "data" ]; then
    echo "  ✓ Profile marker: data"; PASS=$((PASS + 1))
else
    echo "  ✗ Profile marker: expected 'data', got '${PROFILE}'"; FAIL=$((FAIL + 1))
fi

echo ""
echo "Data Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
