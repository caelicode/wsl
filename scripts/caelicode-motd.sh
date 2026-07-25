# shellcheck shell=bash
# CaeliCode WSL — MOTD, update notice, and runtime kick-off
# Sourced (not executed) by interactive bash and zsh via the shipped
# rc files. Living under /opt/caelicode/current/scripts means updates
# refresh this logic without ever touching user dotfiles.
#
# Rules for this file:
#  - POSIX-compatible subset only (bash AND zsh source it)
#  - NEVER touch the network: a network call here would hang every
#    shell start behind a broken proxy. The update notice reads only
#    the local state cache written by the daily systemd check.

# shellcheck disable=SC2317  # exit is the fallback when executed, not sourced
if [ -n "${CAELICODE_MOTD_SHOWN:-}" ]; then return 0 2>/dev/null || exit 0; fi
export CAELICODE_MOTD_SHOWN=1

_cc_cfg="/opt/caelicode/current/scripts/caelicode-config"
[ -x "$_cc_cfg" ] || _cc_cfg="/usr/local/bin/caelicode-config"

_cc_enabled() {
    if [ -x "$_cc_cfg" ]; then "$_cc_cfg" is-enabled "$1" "$2"; else [ "$2" = "true" ]; fi
}

# ── Banner ───────────────────────────────────────────────────────────
if _cc_enabled branding.motd_enabled true; then
    _cc_profile="$(cat /opt/caelicode/PROFILE 2>/dev/null || echo base)"
    _cc_version="$(cat /opt/caelicode/VERSION 2>/dev/null || echo dev)"
    _cc_title="CaeliCode WSL"
    [ -x "$_cc_cfg" ] && _cc_title="$("$_cc_cfg" get branding.motd_text "CaeliCode WSL")"

    printf '\n'
    printf '\033[1;36m  ╔═══════════════════════════════════════════╗\033[0m\n'
    printf '\033[1;36m  ║\033[0m  \033[1;37m%s\033[0m\n' "$_cc_title"
    printf '\033[1;36m  ║\033[0m  \033[0;37mProfile: %s │ Version: %s\033[0m\n' "$_cc_profile" "$_cc_version"
    printf '\033[1;36m  ╚═══════════════════════════════════════════╝\033[0m\n'
    printf '\n'
fi

# ── Update notice (local cache only) ─────────────────────────────────
_cc_state="/var/lib/caelicode/update-state.json"
if [ -r "$_cc_state" ] && command -v jq >/dev/null 2>&1 && _cc_enabled updates.notify_motd true; then
    if [ "$(jq -r '.available // false' "$_cc_state" 2>/dev/null)" = "true" ]; then
        _cc_latest="$(jq -r '.latest // "?"' "$_cc_state" 2>/dev/null)"
        _cc_cur="$(cat /opt/caelicode/VERSION 2>/dev/null || echo '?')"
        if [ "$(jq -r '.requires_reimport // false' "$_cc_state" 2>/dev/null)" = "true" ]; then
            printf '  \033[1;33m⬆ Update available: %s → %s\033[0m\n' "$_cc_cur" "$_cc_latest"
            printf '    Major upgrade — run: \033[1mcaelicode-update --full\033[0m\n\n'
        else
            printf '  \033[1;33m⬆ Update available: %s → %s\033[0m\n' "$_cc_cur" "$_cc_latest"
            printf '    Run: \033[1mcaelicode-update\033[0m\n\n'
        fi
        unset _cc_latest _cc_cur
    fi
fi

# ── Once-per-boot runtime glue (proxy detect, SSH bridge) ────────────
for _cc_rti in /opt/caelicode/current/scripts/caelicode-runtime-init /opt/caelicode/scripts/caelicode-runtime-init; do
    if [ -x "$_cc_rti" ]; then ("$_cc_rti" >/dev/null 2>&1 &); break; fi
done
unset _cc_rti 2>/dev/null || true

unset _cc_profile _cc_version _cc_title _cc_state _cc_cfg 2>/dev/null || true
unset -f _cc_enabled 2>/dev/null || true
