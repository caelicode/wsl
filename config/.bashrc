# ~/.bashrc: CaeliCode WSL shell initialization

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# ── History ──────────────────────────────────────────────────────────
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
HISTSIZE=5000
HISTFILESIZE=50000

# ── Shell Options ────────────────────────────────────────────────────
shopt -s checkwinsize
shopt -s globstar 2>/dev/null

# Less: make it friendlier for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ── Mise (Tool Version Manager) ─────────────────────────────────────
# Shims are already in PATH via /etc/profile.d/00-caelicode-env.sh.
# We do NOT use `mise activate` because its hook-env runs on every
# prompt and can hang in WSL2. See: https://github.com/jdx/mise/discussions/4821
export PATH="/opt/mise/bin:/opt/mise/shims:$PATH"

# ── Starship Prompt ──────────────────────────────────────────────────
export STARSHIP_CONFIG="/etc/caelicode/starship.toml"
if [[ -x /usr/local/bin/starship ]]; then
    eval "$(/usr/local/bin/starship init bash)"
else
    # Fallback PS1 if starship is not available
    _git_branch() {
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        [ -n "$branch" ] && echo " ($branch)"
    }

    _k8s_context() {
        if command -v kubectl &>/dev/null; then
            local ctx
            ctx=$(kubectl config current-context 2>/dev/null)
            [ -n "$ctx" ] && echo " ⎈${ctx}"
        fi
    }

    PS1="\[\033[01;32m\]\u\[\033[0m\]@\[\033[01;34m\]\h\[\033[0m\]:\[\033[01;33m\]\w\[\033[01;35m\]\$(_git_branch)\[\033[01;36m\]\$(_k8s_context)\[\033[0m\]\$ "
fi

# ── Zoxide (smart cd) ────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
fi

# ── Direnv ────────────────────────────────────────────────────────────
if command -v direnv &>/dev/null; then
    eval "$(direnv hook bash)"
fi

# ── FZF Integration ──────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
    eval "$(fzf --bash 2>/dev/null)" || true
fi

# ── CaeliCode MOTD ───────────────────────────────────────────────────
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

# ── Aliases ──────────────────────────────────────────────────────────
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# ── Completions ──────────────────────────────────────────────────────
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Kubectl completion (SRE profile)
if command -v kubectl &>/dev/null; then
    source <(kubectl completion bash 2>/dev/null)
    complete -o default -F __start_kubectl k
fi

# Helm completion (SRE profile)
if command -v helm &>/dev/null; then
    source <(helm completion bash 2>/dev/null)
fi
