# CaeliCode WSL — Zsh Configuration

# If not running interactively, don't do anything
[[ -o interactive ]] || return

# ── Start in home directory (Windows system dirs only) ──────────────
# WSL launched from the Start menu inherits the Windows CWD
# (C:\Windows\System32), where prompt tools scan slowly over the 9P
# mount. Only bounce home from Windows *system* directories — never
# from project paths, so `wsl --cd`, VS Code terminals opened on /mnt
# workspaces, and tmux splits keep their working directory.
[[ "$PWD" == /mnt/c/[Ww][Ii][Nn][Dd][Oo][Ww][Ss]* ]] && cd ~

# ── PATH ─────────────────────────────────────────────────────────
# Clean Linux-only PATH. NO mise shims — all tools are symlinked
# into /opt/mise/bin/ at build time. Windows paths excluded via
# appendWindowsPath=false in /etc/wsl.conf.
export PATH="/opt/mise/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ── History ──────────────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# ── Oh My Zsh ────────────────────────────────────────────────────
export ZSH="/opt/oh-my-zsh"
ZSH_THEME=""  # Disabled — using Starship prompt instead
DISABLE_AUTO_UPDATE=true
DISABLE_MAGIC_FUNCTIONS=true

plugins=(git)
[[ -d "$ZSH/custom/plugins/zsh-autosuggestions" ]] && plugins+=(zsh-autosuggestions)
[[ -d "$ZSH/custom/plugins/zsh-syntax-highlighting" ]] && plugins+=(zsh-syntax-highlighting)
[[ -x /opt/mise/bin/kubectl ]] && plugins+=(kubectl)
[[ -x /opt/mise/bin/terraform ]] && plugins+=(terraform)
command -v docker &>/dev/null && plugins+=(docker)

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# ── Starship Prompt ─────────────────────────────────────────────
export STARSHIP_CONFIG="/etc/caelicode/starship.toml"
if [[ -x /usr/local/bin/starship ]]; then
    eval "$(/usr/local/bin/starship init zsh)"
fi

# ── Zoxide (smart cd) ───────────────────────────────────────────
if [[ -x /opt/mise/bin/zoxide ]]; then
    eval "$(/opt/mise/bin/zoxide init zsh)"
fi

# ── Direnv ───────────────────────────────────────────────────────
if [[ -x /opt/mise/bin/direnv ]]; then
    eval "$(/opt/mise/bin/direnv hook zsh)"
fi

# ── FZF Integration ─────────────────────────────────────────────
if [[ -x /opt/mise/bin/fzf ]]; then
    source <(/opt/mise/bin/fzf --zsh 2>/dev/null) || true
fi

# ── Aliases ──────────────────────────────────────────────────────
if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

# ── SSL/TLS ──────────────────────────────────────────────────────
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export NODE_OPTIONS=--use-openssl-ca

# ── SSH agent bridge socket ─────────────────────────────────────
# Liveness-probe the socket (not just -S): in the /tmp fallback a
# dead socket file survives WSL reboots, and exporting it breaks
# ssh in every shell until it is cleaned up.
if [ -z "${SSH_AUTH_SOCK:-}" ] && command -v socat >/dev/null 2>&1; then
    for _cc_sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/caelicode-ssh-agent.sock" /tmp/caelicode-ssh-agent.sock; do
        if [ -S "$_cc_sock" ] && socat -u OPEN:/dev/null "UNIX-CONNECT:$_cc_sock" 2>/dev/null; then
            export SSH_AUTH_SOCK="$_cc_sock"; break
        fi
    done
    unset _cc_sock
fi

# ── CaeliCode MOTD, update notice & runtime init ────────────────
# (falls back to the legacy flat layout for pre-releases-era images)
for _cc_motd in /opt/caelicode/current/scripts/caelicode-motd.sh /opt/caelicode/scripts/caelicode-motd.sh; do
    if [ -r "$_cc_motd" ]; then source "$_cc_motd"; break; fi
done
unset _cc_motd
