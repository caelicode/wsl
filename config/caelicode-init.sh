#!/bin/sh
# CaeliCode WSL — Lazy init on first interactive login.
# Sourced by /etc/profile.d/ — runs in the user's login shell context
# where Windows interop actually works (unlike boot.command or systemd).

# Only run once per boot (not per shell)
INIT_MARKER="/tmp/.caelicode-init-done"
[ -f "$INIT_MARKER" ] && return 0

# ── DNS fallback ─────────────────────────────────────────────────────
# Ensure resolv.conf is populated so DNS works immediately.
DNSFILE="/etc/resolv.conf"
FALLBACK="/etc/caelicode/resolv.conf.fallback"

if [ ! -s "$DNSFILE" ] && [ -f "$FALLBACK" ]; then
    sudo cp "$FALLBACK" "$DNSFILE" 2>/dev/null || true
fi

# Try to detect Windows DNS and upgrade (backgrounded, non-blocking)
(
    DNSLIST=$(timeout 10 /mnt/c/windows/system32/windowspowershell/v1.0/powershell.exe \
        -NoProfile -NonInteractive -Command \
        "Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses | Sort-Object -Unique" \
        2>/dev/null | tr -d '\r' || true)

    if [ -n "$DNSLIST" ]; then
        printf "" | sudo tee "$DNSFILE" >/dev/null 2>&1
        echo "$DNSLIST" | while IFS= read -r ip; do
            [ -n "$ip" ] && echo "nameserver $ip" | sudo tee -a "$DNSFILE" >/dev/null 2>&1
        done
    fi
) &

# Mark init done for this boot
touch "$INIT_MARKER" 2>/dev/null || true
