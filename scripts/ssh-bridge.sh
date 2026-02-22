#!/usr/bin/env bash
# CaeliCode WSL — SSH agent bridge
# Bridges the Windows OpenSSH agent to a Unix socket in WSL using socat + npiperelay.
# This allows `ssh-add -l`, `git push` over SSH, etc. to use Windows-managed keys.
#
# Prerequisites:
#   - Windows OpenSSH agent running (ssh-agent service)
#   - npiperelay.exe in /mnt/c/tools/ or Windows PATH
#   - socat installed in WSL (included in base image)

set -uo pipefail

SOCKET="/tmp/caelicode-ssh-agent.sock"
NPIPERELAY="/mnt/c/tools/npiperelay.exe"
PIPE="//./pipe/openssh-ssh-agent"

log() { echo "[caelicode-ssh] $*"; }

# Find npiperelay.exe
find_npiperelay() {
    # Check common locations
    for path in \
        "/mnt/c/tools/npiperelay.exe" \
        "/mnt/c/Users/*/go/bin/npiperelay.exe" \
        "/mnt/c/Users/*/scoop/shims/npiperelay.exe"; do
        # shellcheck disable=SC2086,SC2012
        local found
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

# Clean up stale socket
rm -f "$SOCKET"

log "Starting SSH agent bridge: Windows pipe → ${SOCKET}"
exec socat UNIX-LISTEN:"${SOCKET}",fork EXEC:"${NPIPERELAY} -ei -s ${PIPE}",nofork
