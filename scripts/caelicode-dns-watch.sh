#!/usr/bin/env bash
# CaeliCode WSL — DNS health watcher
#
# Opt-in via dns.watch_enabled in /etc/caelicode/config.yaml (default:
# false — this rewrites /etc/resolv.conf, which should be a deliberate
# choice). When resolution fails twice in a row (the classic WSL
# VPN-connect breakage), it re-points resolv.conf at the CURRENT
# Windows DNS servers, falling back to Cloudflare/Google when Windows
# can't be queried.
#
# Started once per boot by caelicode-runtime-init (as root); a lock
# guarantees a single instance.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${SCRIPT_DIR}/caelicode-config"
POWERSHELL="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
RESOLV="/etc/resolv.conf"
LOCK="/run/caelicode-dns-watch.lock"

log() { logger -t caelicode-dns "$*" 2>/dev/null || true; }

if [ "$(id -u)" -ne 0 ]; then
    echo "[caelicode-dns] ERROR: must run as root (rewrites ${RESOLV})" >&2
    exit 1
fi

if [ ! -x "$CFG" ] || ! "$CFG" is-enabled dns.watch_enabled false; then
    exit 0
fi

INTERVAL="$("$CFG" get dns.watch_interval 30)"
[[ "$INTERVAL" =~ ^[0-9]+$ ]] || INTERVAL=30
[ "$INTERVAL" -ge 5 ] || INTERVAL=5

# Single instance per boot ( /run is tmpfs — cleared on reboot )
exec 9>"$LOCK" 2>/dev/null || exec 9>/tmp/caelicode-dns-watch.lock
flock -n 9 || exit 0

dns_ok() {
    timeout 3 getent hosts github.com >/dev/null 2>&1 \
        || timeout 3 getent hosts cloudflare.com >/dev/null 2>&1
}

windows_dns() {
    # Current Windows DNS servers (IPv4), de-duplicated, sans loopback
    # resolvers WSL cannot reach.
    "$POWERSHELL" -NoProfile -NonInteractive -Command \
        'Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses' \
        2>/dev/null | tr -d '\r' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
        | grep -v '^127\.' | awk '!seen[$0]++' | head -3
}

rewrite_resolv() {
    local servers="$1"
    {
        echo "# Rewritten by caelicode-dns-watch ($(date -Is)) after DNS failure."
        echo "# Disable via dns.watch_enabled in /etc/caelicode/config.yaml."
        while IFS= read -r s; do
            [ -n "$s" ] && echo "nameserver $s"
        done <<< "$servers"
    } > "$RESOLV"
}

log "watching DNS health every ${INTERVAL}s"
FAILS=0
while sleep "$INTERVAL"; do
    if dns_ok; then
        FAILS=0
        continue
    fi
    FAILS=$((FAILS + 1))
    [ "$FAILS" -lt 2 ] && continue

    SERVERS="$(windows_dns || true)"
    if [ -z "$SERVERS" ]; then
        SERVERS=$'1.1.1.1\n8.8.8.8'
        log "DNS broken; Windows DNS unavailable — using public fallback"
    fi
    rewrite_resolv "$SERVERS"
    log "resolv.conf re-pointed at: $(tr '\n' ' ' <<< "$SERVERS")"
    FAILS=0
done
