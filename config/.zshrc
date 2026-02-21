# CaeliCode WSL — Zsh Configuration

# If not running interactively, don't do anything
[[ -o interactive ]] || return

# ── Oh My Zsh ──────────────────────────────────────────────────────
export ZSH="/opt/oh-my-zsh"
ZSH_THEME=""  # Disabled — using Starship prompt instead

# Only load plugins that exist
plugins=(git)
[[ -d "$ZSH/custom/plugins/zsh-autosuggestions" ]] && plugins+=(zsh-autosuggestions)
[[ -d "$ZSH/custom/plugins/zsh-syntax-highlighting" ]] && plugins+=(zsh-syntax-highlighting)
command -v kubectl &>/dev/null && plugins+=(kubectl)
command -v terraform &>/dev/null && plugins+=(terraform)
command -v docker &>/dev/null && plugins+=(docker)

source "$ZSH/oh-my-zsh.sh"

# ── History ────────────────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# ── Mise (Tool Version Manager) ───────────────────────────────────
export PATH="/opt/mise/bin:/opt/mise/shims:$PATH"
if command -v mise &>/dev/null; then
    eval "$(mise activate zsh)"
fi

# ── Starship Prompt ───────────────────────────────────────────────
export STARSHIP_CONFIG="/etc/caelicode/starship.toml"
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# ── Zoxide (smart cd) ─────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# ── Direnv ─────────────────────────────────────────────────────────
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# ── FZF Integration ───────────────────────────────────────────────
if command -v fzf &>/dev/null; then
    source <(fzf --zsh 2>/dev/null) || true
fi

# ── Aliases ────────────────────────────────────────────────────────
if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

# ── SSL/TLS ────────────────────────────────────────────────────────
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export NODE_OPTIONS=--use-openssl-ca

# ── CaeliCode MOTD ────────────────────────────────────────────────
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
