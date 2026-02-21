#!/usr/bin/env bash
# CaeliCode WSL — Boot script
# Runs at WSL startup via wsl.conf [boot] command.
# Handles first-run setup and starts background services.
#
# This replaces systemd services to avoid boot hangs caused by
# WSL2's systemd implementation on Docker-exported images.

set -uo pipefail

LOG_TAG="caelicode-boot"
SETUP_MARKER="/opt/caelicode/.setup-done"

log() { logger -t "$LOG_TAG" "$*" 2>/dev/null; echo "[${LOG_TAG}] $*"; }
warn() { logger -t "$LOG_TAG" "WARNING: $*" 2>/dev/null; echo "[${LOG_TAG}] WARNING: $*" >&2; }

# Timeout wrapper — prevents Windows interop calls from blocking boot.
run_with_timeout() {
    local secs="$1"; shift
    timeout --signal=KILL "$secs" "$@" 2>/dev/null || true
}

# ── First-run setup (only runs once) ────────────────────────────────
if [ ! -f "$SETUP_MARKER" ]; then
    log "First boot detected — running initial setup..."

    # ── User Creation ────────────────────────────────────────────────
    RAWUSER=$(run_with_timeout 10 /mnt/c/windows/system32/cmd.exe /c "echo %USERNAME%" | tr -d '\r' || true)
    NEWUSER=$(echo "$RAWUSER" | awk -F'\\\\' '{print $NF}' | awk -F'/' '{print $NF}')

    if [ -z "$NEWUSER" ]; then
        warn "Could not detect Windows username — falling back to 'caelicode'"
        NEWUSER="caelicode"
    fi

    # Sanitize: lowercase, no spaces
    NEWUSER=$(echo "$NEWUSER" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

    if getent passwd "$NEWUSER" >/dev/null 2>&1; then
        log "User '$NEWUSER' already exists — skipping creation"
    else
        log "Creating user '$NEWUSER' with sudo access..."
        useradd -ms /bin/zsh "$NEWUSER"
        usermod -aG sudo "$NEWUSER"
        echo "${NEWUSER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${NEWUSER}"
        chmod 0440 "/etc/sudoers.d/${NEWUSER}"
        log "User '$NEWUSER' created successfully"
    fi

    # Set as default WSL login user
    if ! grep -q "default=${NEWUSER}" /etc/wsl.conf 2>/dev/null; then
        echo -e "\n[user]\ndefault=${NEWUSER}" >> /etc/wsl.conf
        log "Default WSL user set to '${NEWUSER}'"
    fi

    # ── Shell Config ─────────────────────────────────────────────────
    USER_HOME="/home/${NEWUSER}"
    for f in .bashrc .bash_aliases .zshrc; do
        if [ ! -f "${USER_HOME}/${f}" ] || [ ! -s "${USER_HOME}/${f}" ]; then
            cp "/etc/skel/${f}" "${USER_HOME}/${f}" 2>/dev/null || true
            chown "${NEWUSER}:${NEWUSER}" "${USER_HOME}/${f}" 2>/dev/null || true
        fi
    done

    touch "$SETUP_MARKER"
    log "First-run setup complete"
fi

# ── DNS ──────────────────────────────────────────────────────────────
# Ensure resolv.conf has at least fallback DNS
DNSFILE="/etc/resolv.conf"
FALLBACK="/etc/caelicode/resolv.conf.fallback"

if [ ! -s "$DNSFILE" ] && [ -f "$FALLBACK" ]; then
    cp "$FALLBACK" "$DNSFILE"
    log "Applied fallback DNS"
fi

# Try to upgrade with Windows DNS (backgrounded to not block shell)
(
    DNSLIST=$(run_with_timeout 15 /mnt/c/windows/system32/windowspowershell/v1.0/powershell.exe \
        -NoProfile -NonInteractive -Command \
        "Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses | Sort-Object -Unique" \
        | tr -d '\r' || true)

    if [ -n "$DNSLIST" ]; then
        : > "$DNSFILE"
        for ip in $DNSLIST; do
            echo "nameserver $ip" >> "$DNSFILE"
        done
        log "DNS upgraded to $(echo "$DNSLIST" | wc -w) Windows nameservers"
    fi
) &

# ── Start background services ────────────────────────────────────────
# DNS watcher (polls Windows DNS for VPN/network changes)
if [ -x /opt/caelicode/scripts/dns-watch.sh ]; then
    nohup /opt/caelicode/scripts/dns-watch.sh >/dev/null 2>&1 &
fi

# SSH agent bridge (requires npiperelay.exe on Windows side)
if [ -x /opt/caelicode/scripts/ssh-bridge.sh ]; then
    nohup /opt/caelicode/scripts/ssh-bridge.sh >/dev/null 2>&1 &
fi

log "Boot complete"
