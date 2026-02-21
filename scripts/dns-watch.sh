#!/usr/bin/env bash
# CaeliCode WSL — Dynamic DNS watcher
# Polls Windows DNS configuration and updates /etc/resolv.conf when changes
# are detected (e.g., VPN connect/disconnect, network switch).
#
# Runs as a systemd service with automatic restart.

set -uo pipefail

DNSFILE="/etc/resolv.conf"
CACHE_FILE="/tmp/.caelicode-dns-cache"
INTERVAL=${DNS_WATCH_INTERVAL:-5}

log() { echo "[caelicode-dns] $*"; }

get_windows_dns() {
    /mnt/c/windows/system32/windowspowershell/v1.0/powershell.exe \
        -NoProfile -NonInteractive -Command \
        "Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses | Sort-Object -Unique" \
        2>/dev/null | tr -d '\r' | sort -u | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true
}

get_current_dns() {
    grep -E '^nameserver ' "$DNSFILE" 2>/dev/null | awk '{print $2}' | sort -u || true
}

update_resolv_conf() {
    local dns_list="$1"
    : > "$DNSFILE"
    while IFS= read -r ip; do
        [ -n "$ip" ] && echo "nameserver $ip" >> "$DNSFILE"
    done <<< "$dns_list"
    log "Updated resolv.conf with: $(echo "$dns_list" | tr '\n' ' ')"
}

log "DNS watcher started (interval: ${INTERVAL}s)"

while true; do
    WINDOWS_DNS=$(get_windows_dns)
    CURRENT_DNS=$(get_current_dns)

    if [ -z "$WINDOWS_DNS" ]; then
        sleep "$INTERVAL"
        continue
    fi

    # Compare sorted DNS lists
    WIN_HASH=$(echo "$WINDOWS_DNS" | md5sum | awk '{print $1}')
    CUR_HASH=$(echo "$CURRENT_DNS" | md5sum | awk '{print $1}')

    if [ "$WIN_HASH" != "$CUR_HASH" ]; then
        log "DNS change detected — updating resolv.conf"
        update_resolv_conf "$WINDOWS_DNS"
    fi

    sleep "$INTERVAL"
done
