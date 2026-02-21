# CaeliCode WSL — Zsh Configuration

# If not running interactively, don't do anything
[[ -o interactive ]] || return

# ── Helper: timeout-protected eval ───────────────────────────────
# Prevents any single init command from hanging the shell.
_timed_eval() {
    local out
    out=$(timeout 5 "$@" 2>/dev/null) && eval "$out"
}

# ── PATH (must come first) ───────────────────────────────────────
export PATH="/opt/mise/bin:/opt/mise/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# ── History ────────────────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# ── Oh My Zsh ──────────────────────────────────────────────────────
export ZSH="/opt/oh-my-zsh"
ZSH_THEME=""  # Disabled — using Starship prompt instead
DISABLE_AUTO_UPDATE=true
DISABLE_MAGIC_FUNCTIONS=true

# Only load lightweight plugins — skip kubectl/terraform/docker
# as they run slow completion init on every shell start
plugins=(git)
[[ -d "$ZSH/custom/plugins/zsh-autosuggestions" ]] && plugins+=(zsh-autosuggestions)
[[ -d "$ZSH/custom/plugins/zsh-syntax-highlighting" ]] && plugins+=(zsh-syntax-highlighting)

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# ── Mise (Tool Version Manager) ───────────────────────────────────
# Shims already provide tool access via PATH. `mise activate` adds
# directory-based auto-switching hooks — skip if it hangs.
if command -v mise &>/dev/null; then
    _timed_eval mise activate zsh
fi

# ── Starship Prompt ───────────────────────────────────────────────
export STARSHIP_CONFIG="/etc/caelicode/starship.toml"
if command -v starship &>/dev/null; then
    _timed_eval starship init zsh
fi

# ── Zoxide (smart cd) ─────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
    _timed_eval zoxide init zsh
fi

# ── Direnv ─────────────────────────────────────────────────────────
if command -v direnv &>/dev/null; then
    _timed_eval direnv hook zsh
fi

# ── FZF Integration ───────────────────────────────────────────────
if command -v fzf &>/dev/null; then
    _timed_eval fzf --zsh
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

# Cleanup
unfunction _timed_eval 2>/dev/null
