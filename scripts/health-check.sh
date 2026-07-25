#!/usr/bin/env bash
# CaeliCode WSL — Environment health check
# Validates that the WSL environment is functioning correctly.
#
# Usage: health-check.sh [--quiet]

set -uo pipefail

# Ensure the tool symlink dir is in PATH — Docker ENV is lost after
# wsl --import, and `wsl -- command` runs a non-interactive shell.
# NOTE: deliberately NOT /opt/mise/shims — shims hang in WSL (they
# trigger mise version resolution with network calls); the runtime
# contract is direct symlinks in /opt/mise/bin only.
if [[ ":$PATH:" != *":/opt/mise/bin:"* ]]; then
    export PATH="/opt/mise/bin:$PATH"
fi

QUIET=false
[ "${1:-}" = "--quiet" ] && QUIET=true

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); $QUIET || echo "  ✓ $*"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ $*" >&2; }
warn() { WARN=$((WARN + 1)); $QUIET || echo "  ! $*"; }

section() { $QUIET || echo -e "\n── $* ──"; }

# ── System ───────────────────────────────────────────────────────────
section "System"

if [ -f /opt/caelicode/VERSION ]; then pass "Version: $(cat /opt/caelicode/VERSION)"; else fail "Version file missing"; fi
if [ -f /opt/caelicode/PROFILE ]; then pass "Profile: $(cat /opt/caelicode/PROFILE)"; else fail "Profile file missing"; fi
if [ -f /etc/caelicode/config.yaml ]; then pass "Config: /etc/caelicode/config.yaml"; else warn "Config file missing"; fi
if [ -L /opt/caelicode/current ] && [ -d /opt/caelicode/current/scripts ]; then
    pass "Release layout: current → $(readlink /opt/caelicode/current)"
elif [ -d /opt/caelicode/scripts ]; then
    warn "Legacy flat layout (run caelicode-update to migrate)"
else
    fail "No CaeliCode scripts directory found"
fi

# ── Updates ──────────────────────────────────────────────────────────
section "Updates"

STATE_FILE=/var/lib/caelicode/update-state.json
if [ -r "$STATE_FILE" ] && command -v jq >/dev/null 2>&1; then
    if [ "$(jq -r '.available // false' "$STATE_FILE" 2>/dev/null)" = "true" ]; then
        LATEST="$(jq -r '.latest // "?"' "$STATE_FILE" 2>/dev/null)"
        if [ "$(jq -r '.requires_reimport // false' "$STATE_FILE" 2>/dev/null)" = "true" ]; then
            warn "Update available: ${LATEST} (requires re-import — caelicode-update --full)"
        else
            warn "Update available: ${LATEST} (run: caelicode-update)"
        fi
    else
        pass "Up to date as of $(jq -r '.checked_at // "?"' "$STATE_FILE" 2>/dev/null)"
    fi
else
    warn "No update check has run yet (caelicode-update --check)"
fi

# ── Tools ────────────────────────────────────────────────────────────
section "Tools"

for cmd in git curl jq mise python3; do
    if command -v "$cmd" &>/dev/null; then
        ver="$($cmd --version 2>/dev/null | head -1 || echo "ok")"
        pass "$cmd: $ver"
    else
        fail "$cmd not found"
    fi
done

# Profile-specific tools
PROFILE="$(cat /opt/caelicode/PROFILE 2>/dev/null || echo "base")"

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

NS="$(grep -c '^nameserver' /etc/resolv.conf 2>/dev/null || true)"
NS="${NS:-0}"
if [ "$NS" -gt 0 ] 2>/dev/null; then
    pass "DNS configured (${NS} nameserver(s))"
else
    fail "No nameservers in /etc/resolv.conf — DNS broken"
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

BRIDGE_SOCK="${XDG_RUNTIME_DIR:-/tmp}/caelicode-ssh-agent.sock"
if [ -S "${SSH_AUTH_SOCK:-}" ]; then
    # ssh-add exit codes: 0 = keys listed, 1 = agent reachable but empty,
    # 2 = cannot contact agent. Counting output lines miscounts the
    # "The agent has no identities." message as a key.
    ssh-add -l >/dev/null 2>&1
    case $? in
        0)
            KEYS="$(ssh-add -l 2>/dev/null | grep -c . || true)"
            pass "SSH agent connected (${KEYS} key(s))"
            ;;
        1)
            pass "SSH agent connected (no keys loaded — add them in Windows: ssh-add)"
            ;;
        *)
            warn "SSH_AUTH_SOCK is set but the agent is not responding"
            ;;
    esac
elif [ -S "$BRIDGE_SOCK" ] || [ -S /tmp/caelicode-ssh-agent.sock ]; then
    warn "SSH bridge socket exists but SSH_AUTH_SOCK is not set (open a new shell)"
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
