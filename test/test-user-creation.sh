#!/usr/bin/env bash
# CaeliCode WSL — User creation tests
# Tests that the pre-created default user is correctly configured.
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

# Default user exists and is configured correctly
check "caelicode user exists" getent passwd caelicode
check "caelicode home dir" test -d /home/caelicode
check "caelicode shell is zsh" grep -q "caelicode.*/bin/zsh" /etc/passwd
check "caelicode in sudo group" id -nG caelicode
check "caelicode sudoers file" test -f /etc/sudoers.d/caelicode

# Shell config is in place
check "caelicode has .zshrc" test -f /home/caelicode/.zshrc
check "caelicode has .bashrc" test -f /home/caelicode/.bashrc
check "caelicode has .bash_aliases" test -f /home/caelicode/.bash_aliases

# Skel files available for future users
check "Skel .bashrc available" test -f /etc/skel/.bashrc
check "Skel .bash_aliases available" test -f /etc/skel/.bash_aliases
check "Skel .zshrc available" test -f /etc/skel/.zshrc

# WSL default user is set
check "wsl.conf default user" grep -q "default = caelicode" /etc/wsl.conf

echo ""
echo "User Creation Results: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
