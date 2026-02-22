# CaeliCode WSL — Zsh Configuration

# If not running interactively, don't do anything
[[ -o interactive ]] || return

# ── Start in home directory ──────────────────────────────────────
# WSL inherits the Windows CWD (e.g. /mnt/c/Windows/System32) which
# causes tools to scan slowly over the 9P mount.
[[ "$PWD" == /mnt/* ]] && cd ~

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
