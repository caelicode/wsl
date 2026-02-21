#!/usr/bin/env bash
# CaeliCode WSL — First-login automation
# Runs once via systemd on first boot to configure the environment.
#
# Actions:
#   1. Creates a non-root user matching the Windows username
#   2. Grants sudo access (passwordless)
#   3. Sets the user as WSL default login
#   4. Initializes DNS resolution from Windows config
#   5. Copies shell config to the new user's home directory
#
# Status: sudo systemctl status run-once.service
# Re-run: sudo systemctl restart run-once.service

set -euo pipefail

LOG_TAG="caelicode-run-once"

log() { echo "[${LOG_TAG}] $*"; }
warn() { echo "[${LOG_TAG}] WARNING: $*" >&2; }

# Timeout wrapper — prevents Windows interop calls from blocking boot.
# WSL's cmd.exe / powershell.exe can hang when the interop pipe isn't ready.
run_with_timeout() {
    local secs="$1"; shift
    timeout --signal=KILL "$secs" "$@" 2>/dev/null || true
}

# ── User Creation ────────────────────────────────────────────────────
# Extract Windows username (strip domain prefix if present)
# Uses timeout to avoid hanging if Windows interop isn't ready
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
    # Passwordless sudo for convenience (user can harden later)
    echo "${NEWUSER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${NEWUSER}"
    chmod 0440 "/etc/sudoers.d/${NEWUSER}"
    log "User '$NEWUSER' created successfully"
fi

# Set as default WSL login user
if ! grep -q "default=${NEWUSER}" /etc/wsl.conf 2>/dev/null; then
    echo -e "\n[user]\ndefault=${NEWUSER}" >> /etc/wsl.conf
    log "Default WSL user set to '${NEWUSER}'"
fi

# ── Shell Config ─────────────────────────────────────────────────────
USER_HOME="/home/${NEWUSER}"

# Copy CaeliCode shell config if user doesn't already have custom ones
for f in .bashrc .bash_aliases .zshrc; do
    if [ ! -f "${USER_HOME}/${f}" ] || [ ! -s "${USER_HOME}/${f}" ]; then
        cp "/etc/skel/${f}" "${USER_HOME}/${f}" 2>/dev/null || true
        chown "${NEWUSER}:${NEWUSER}" "${USER_HOME}/${f}" 2>/dev/null || true
    fi
done

# ── DNS Initialization ───────────────────────────────────────────────
DNSFILE="/etc/resolv.conf"

if [ -s "$DNSFILE" ]; then
    log "DNS already configured in ${DNSFILE}"
else
    log "Initializing DNS from Windows configuration..."
    DNSLIST=$(run_with_timeout 15 /mnt/c/windows/system32/windowspowershell/v1.0/powershell.exe \
        -NoProfile -NonInteractive -Command \
        "Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses | Sort-Object -Unique" \
        | tr -d '\r' || true)

    if [ -n "$DNSLIST" ]; then
        : > "$DNSFILE"
        for ip in $DNSLIST; do
            echo "nameserver $ip" >> "$DNSFILE"
        done
        log "DNS configured with $(echo "$DNSLIST" | wc -w) nameservers"
    else
        # Fallback to well-known public DNS
        echo "nameserver 1.1.1.1" > "$DNSFILE"
        echo "nameserver 8.8.8.8" >> "$DNSFILE"
        warn "Could not detect Windows DNS — using Cloudflare/Google fallback"
    fi
fi

log "First-login setup complete"
