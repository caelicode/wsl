# CaeliCode WSL — Zsh Configuration

# If not running interactively, don't do anything
[[ -o interactive ]] || return

# ── Start in home directory ──────────────────────────────────────
# WSL inherits the Windows CWD (e.g. /mnt/c/Windows/System32) which
# causes tools to scan slowly over the 9P mount.
[[ "$PWD" == /mnt/* ]] && cd ~

# ── PATH ─────────────────────────────────────────────────────────
# Set a clean Linux-only PATH. Windows paths are excluded via
# appendWindowsPath=false in /etc/wsl.conf to avoid 9P overhead.
# Put /opt/mise/bin BEFORE /opt/mise/shims so the real starship
# binary (symlinked at build time) is found before the mise shim.
export PATH="/opt/mise/bin:/opt/mise/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

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
command -v kubectl &>/dev/null && plugins+=(kubectl)
command -v terraform &>/dev/null && plugins+=(terraform)
command -v docker &>/dev/null && plugins+=(docker)

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# ── Mise (Tool Version Manager) ─────────────────────────────────
# Use `mise activate` for interactive shells (provides env vars and
# hooks). Do NOT combine with shims in PATH — there is a known bug
# (jdx/mise#4444) where activate fails to remove shims from PATH.
# We keep shims in PATH above only as a fallback for non-interactive
# contexts; activate takes precedence in interactive sessions.
if command -v mise &>/dev/null; then
    eval "$(mise activate zsh)"
fi

# ── Starship Prompt ─────────────────────────────────────────────
# The real starship binary is symlinked into /opt/mise/bin/ at
# Docker build time (see Dockerfile). This directory is before
# /opt/mise/shims/ in PATH, so the real binary is used instead of
# the mise shim which hangs in WSL.
export STARSHIP_CONFIG="/etc/caelicode/starship.toml"
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# ── Zoxide (smart cd) ───────────────────────────────────────────
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# ── Direnv ───────────────────────────────────────────────────────
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# ── FZF Integration ─────────────────────────────────────────────
if command -v fzf &>/dev/null; then
    source <(fzf --zsh 2>/dev/null) || true
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

# ── CaeliCode MOTD ──────────────────────────────────────────────
if [ -z "$CAELICODE_MOTD_SHOWN" ]; then
    export CAELICODE_MOTD_SHOWN=1
    PROFILE=$(cat /opt/caelicode/PROFILE 2>/dev/null || echo "base")
    VERSION=$(cat /opt/caelicode/VERSION 2>/dev/null || echo "dev")

    echo ""
    echo -e "\033[1;36m  ╔═══════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;36m  ║\033[0m  \033[1;37mCaeliCode WSL\033[0m"
    echo -e "\033[1;36m  ║\033[0m  \033[0;37mProfile: ${PROFILE} │ Version: ${VERSION}\033[0m"
    echo -e "\033[1;36m  ╚═══════════════════════════════════════════╝\033[0m"
    echo ""
fi
