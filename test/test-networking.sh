#!/usr/bin/env bash
# CaeliCode WSL — Networking tests (run inside container)
set -euo pipefail

# shellcheck source=test/common.sh
source "$(dirname "$0")/common.sh"

echo "── Networking Tests ──"

check "curl installed" command -v curl
check "dig installed" command -v dig
check "socat installed" command -v socat

# DNS resolution (works in CI, not in offline builds)
if curl -sf --max-time 5 https://github.com >/dev/null 2>&1; then
    check "DNS resolves github.com" dig +short github.com
    check "HTTPS to github.com" curl -sf --max-time 10 https://github.com
    check "HTTPS to pypi.org" curl -sf --max-time 10 https://pypi.org
else
    echo "  ! Skipping online tests (no internet)"
fi

# SSL cert bundle
check "CA bundle exists" test -f /etc/ssl/certs/ca-certificates.crt
check "CA bundle non-empty" test -s /etc/ssl/certs/ca-certificates.crt

summarize "Networking Results"
