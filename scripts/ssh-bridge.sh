#!/usr/bin/env bash
# CaeliCode WSL — SSH agent bridge
# Bridges the Windows OpenSSH agent to a Unix socket in WSL using socat + npiperelay.
# This allows `ssh-add -l`, `git push` over SSH, etc. to use Windows-managed keys.
#
# Started once per boot by caelicode-runtime-init (gated on
# ssh.agent_forwarding in /etc/caelicode/config.yaml). Shell init exports
# SSH_AUTH_SOCK when the socket exists.
#
# Prerequisites:
#   - Windows OpenSSH agent running (ssh-agent service)
#   - npiperelay.exe in C:\tools\ or a known install location
#   - socat installed in WSL (included in base image)

set -uo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
SOCKET="${RUNTIME_DIR}/caelicode-ssh-agent.sock"
PIPE="//./pipe/openssh-ssh-agent"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[caelicode-ssh] $*"; }

# Respect the config switch even when invoked directly.
CFG="${SCRIPT_DIR}/caelicode-config"
if [ -x "$CFG" ] && ! "$CFG" is-enabled ssh.agent_forwarding true; then
    log "ssh.agent_forwarding is disabled in /etc/caelicode/config.yaml"
    exit 0
fi

# Find npiperelay.exe
find_npiperelay() {
    # Check common locations
    for path in \
        "/mnt/c/tools/npiperelay.exe" \
        "/mnt/c/Users/*/go/bin/npiperelay.exe" \
        "/mnt/c/Users/*/scoop/shims/npiperelay.exe"; do
        local found
        # shellcheck disable=SC2086,SC2012
        found="$(ls $path 2>/dev/null | head -1)"
        if [ -n "$found" ] && [ -x "$found" ]; then
            echo "$found"
            return 0
        fi
    done
    return 1
}

if ! command -v socat &>/dev/null; then
    log "ERROR: socat not installed — SSH agent bridge unavailable"
    exit 1
fi

NPIPERELAY="$(find_npiperelay || true)"
if [ -z "$NPIPERELAY" ]; then
    log "WARNING: npiperelay.exe not found — SSH agent bridge unavailable"
    log "Install it: go install github.com/jstarks/npiperelay@latest"
    log "Then copy to C:\\tools\\npiperelay.exe"
    exit 0
fi

# Another bridge already serving this boot? Nothing to do.
if [ -S "$SOCKET" ] && socat -u OPEN:/dev/null UNIX-CONNECT:"$SOCKET" 2>/dev/null; then
    log "Bridge already running at ${SOCKET}"
    exit 0
fi

# Clean up stale socket
rm -f "$SOCKET"

log "Starting SSH agent bridge: Windows pipe → ${SOCKET}"
# mode=600: the socket fronts the user's private keys — never group/world.
exec socat "UNIX-LISTEN:${SOCKET},fork,mode=600" "EXEC:${NPIPERELAY} -ei -s ${PIPE},nofork"
