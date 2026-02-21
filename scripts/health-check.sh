#!/usr/bin/env bash
# CaeliCode WSL — Environment health check
# Validates that the WSL environment is functioning correctly.
#
# Usage: health-check.sh [--quiet]

set -uo pipefail

QUIET=false
[ "${1:-}" = "--quiet" ] && QUIET=true

PASS=0
FAIL=0
WARN=0

pass() { ((PASS++)); $QUIET || echo "  ✓ $*"; }
fail() { ((FAIL++)); echo "  ✗ $*" >&2; }
warn() { ((WARN++)); $QUIET || echo "  ! $*"; }

section() { $QUIET || echo -e "\n── $* ──"; }

# ── System ───────────────────────────────────────────────────────────
section "System"

[ -f /opt/caelicode/VERSION ] && pass "Version: $(cat /opt/caelicode/VERSION)" || fail "Version file missing"
[ -f /opt/caelicode/PROFILE ] && pass "Profile: $(cat /opt/caelicode/PROFILE)" || fail "Profile file missing"
[ -f /etc/caelicode/config.yaml ] && pass "Config: /etc/caelicode/config.yaml" || warn "Config file missing"

# ── Tools ────────────────────────────────────────────────────────────
section "Tools"

for cmd in git curl jq mise python3; do
    if command -v "$cmd" &>/dev/null; then
        ver=$($cmd --version 2>/dev/null | head -1 || echo "ok")
        pass "$cmd: $ver"
    else
        fail "$cmd not found"
    fi
done

# Profile-specific tools
PROFILE=$(cat /opt/caelicode/PROFILE 2>/dev/null || echo "base")

if [ "$PROFILE" = "sre" ]; then
    for cmd in kubectl helm terraform k9s argocd; do
        if command -v "$cmd" &>/dev/null; then
            pass "$cmd available"
        else
            fail "$cmd not found (expected for SRE profile)"
        fi
    done
fi

if [ "$PROFILE" = "dev" ]; then
    for cmd in node go rustc podman; do
        if command -v "$cmd" &>/dev/null; then
            pass "$cmd available"
        else
            fail "$cmd not found (expected for Dev profile)"
        fi
    done
fi

if [ "$PROFILE" = "data" ]; then
    for cmd in python3 dbt psql; do
        if command -v "$cmd" &>/dev/null; then
            pass "$cmd available"
        else
            warn "$cmd not found (expected for Data profile)"
        fi
    done
fi

# ── Networking ───────────────────────────────────────────────────────
section "Networking"

if [ -s /etc/resolv.conf ]; then
    NS=$(grep -c "^nameserver" /etc/resolv.conf || echo "0")
    pass "DNS configured (${NS} nameservers)"
else
    fail "resolv.conf is empty — DNS broken"
fi

if curl -sf --max-time 5 https://github.com >/dev/null 2>&1; then
    pass "Internet connectivity (github.com reachable)"
elif curl -sf --max-time 5 https://1.1.1.1 >/dev/null 2>&1; then
    warn "DNS may be broken but raw IP works (1.1.1.1 reachable)"
else
    fail "No internet connectivity"
fi

# ── SSH Agent ────────────────────────────────────────────────────────
section "SSH Agent"

if [ -S "${SSH_AUTH_SOCK:-}" ]; then
    KEYS=$(ssh-add -l 2>/dev/null | wc -l || echo "0")
    pass "SSH agent connected (${KEYS} keys)"
elif [ -S "/tmp/caelicode-ssh-agent.sock" ]; then
    warn "SSH bridge socket exists but SSH_AUTH_SOCK not set"
else
    warn "SSH agent bridge not running (optional — needs npiperelay.exe)"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "Health check: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
