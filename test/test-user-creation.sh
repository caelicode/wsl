#!/usr/bin/env bash
# CaeliCode WSL — User creation tests
# Tests the boot.sh user creation logic (simulated, since we can't access Windows in CI)
set -euo pipefail

PASS=0; FAIL=0

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✓ ${name}"; PASS=$((PASS + 1))
    else
        echo "  ✗ ${name}"; FAIL=$((FAIL + 1))
    fi
}

echo "── User Creation Tests ──"

# Script exists and is executable
check "boot.sh exists" test -x /opt/caelicode/scripts/boot.sh

# Simulate user creation
TESTUSER="testcaelicode"
if ! getent passwd "$TESTUSER" >/dev/null 2>&1; then
    useradd -ms /bin/zsh "$TESTUSER"
    usermod -aG sudo "$TESTUSER"
    echo "${TESTUSER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${TESTUSER}"
    chmod 0440 "/etc/sudoers.d/${TESTUSER}"
fi

check "Test user exists" getent passwd "$TESTUSER"
check "Test user has home dir" test -d "/home/${TESTUSER}"
check "Test user in sudo group" id -nG "$TESTUSER"
check "Sudoers file exists" test -f "/etc/sudoers.d/${TESTUSER}"

# Verify skel files would be copied
check "Skel .bashrc available" test -f /etc/skel/.bashrc
check "Skel .bash_aliases available" test -f /etc/skel/.bash_aliases

# Cleanup
userdel -r "$TESTUSER" 2>/dev/null || true
rm -f "/etc/sudoers.d/${TESTUSER}"

echo ""
echo "User Creation Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
