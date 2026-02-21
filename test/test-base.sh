#!/usr/bin/env bash
# CaeliCode WSL — Base profile tests
set -euo pipefail

PASS=0; FAIL=0

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✓ ${name}"; ((PASS++))
    else
        echo "  ✗ ${name}"; ((FAIL++))
    fi
}

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

echo "── Base Profile Tests ──"

# Core tools
check_version "git" "git --version"
check_version "curl" "curl --version"
check_version "jq" "jq --version"
check_version "python3" "python3 --version"
check_version "mise" "mise --version"

# CaeliCode structure
check "VERSION file exists" test -f /opt/caelicode/VERSION
check "PROFILE file exists" test -f /opt/caelicode/PROFILE
check "config.yaml exists" test -f /etc/caelicode/config.yaml
check "wsl.conf exists" test -f /etc/wsl.conf
check "run-once.sh exists" test -x /opt/caelicode/scripts/run-once.sh
check "dns-watch.sh exists" test -x /opt/caelicode/scripts/dns-watch.sh
check "health-check.sh exists" test -x /opt/caelicode/scripts/health-check.sh
check "caelicode-update exists" test -x /opt/caelicode/scripts/caelicode-update
check "caelicode-update in PATH" test -L /usr/local/bin/caelicode-update

# Shell config
check "bashrc in skel" test -f /etc/skel/.bashrc
check "bash_aliases in skel" test -f /etc/skel/.bash_aliases

# WSL config
check "systemd enabled in wsl.conf" grep -q "systemd = true" /etc/wsl.conf
check "generateResolvConf disabled" grep -q "generateResolvConf = false" /etc/wsl.conf

# SSL/TLS
check "ca-certificates bundle exists" test -f /etc/ssl/certs/ca-certificates.crt

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
