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
export PATH="/opt/mise/bin:/opt/mise/shims:$PATH"
if command -v mise &>/dev/null; then
    eval "$(mise activate bash)"
fi

# ── CaeliCode Branding ──────────────────────────────────────────────
CAELICODE_CONFIG="/etc/caelicode/config.yaml"

# Parse simple YAML values (key: value) without external deps
_cc_config() {
    local key="$1" default="$2"
    if [ -f "$CAELICODE_CONFIG" ]; then
        local val
        val=$(grep -E "^\s+${key}:" "$CAELICODE_CONFIG" 2>/dev/null | head -1 | sed 's/.*: *//' | tr -d '"')
        [ -n "$val" ] && echo "$val" || echo "$default"
    else
        echo "$default"
    fi
}

# MOTD on login
if [ "$(_cc_config motd_enabled true)" = "true" ]; then
    if [ -z "$CAELICODE_MOTD_SHOWN" ]; then
        export CAELICODE_MOTD_SHOWN=1
        MOTD_TEXT=$(_cc_config motd_text "CaeliCode WSL")
        PROFILE=$(cat /opt/caelicode/PROFILE 2>/dev/null || echo "base")
        VERSION=$(cat /opt/caelicode/VERSION 2>/dev/null || echo "dev")

        echo ""
        echo -e "\033[1;36m  ╔═══════════════════════════════════════════╗\033[0m"
        echo -e "\033[1;36m  ║\033[0m  \033[1;37m${MOTD_TEXT}\033[0m"
        echo -e "\033[1;36m  ║\033[0m  \033[0;37mProfile: ${PROFILE} │ Version: ${VERSION}\033[0m"
        echo -e "\033[1;36m  ╚═══════════════════════════════════════════╝\033[0m"
        echo ""
    fi
fi

# ── PS1 Prompt ───────────────────────────────────────────────────────
_git_branch() {
    if [ "$(_cc_config prompt_git_branch true)" = "true" ]; then
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        [ -n "$branch" ] && echo " ($branch)"
    fi
}

_k8s_context() {
    if [ "$(_cc_config prompt_k8s_context true)" = "true" ] && command -v kubectl &>/dev/null; then
        local ctx
        ctx=$(kubectl config current-context 2>/dev/null)
        [ -n "$ctx" ] && echo " ⎈${ctx}"
    fi
}

# Color codes from config (defaults: green user, blue host, yellow path, magenta git, cyan k8s)
C_USER="\[\033[01;$(_cc_config user 32)m\]"
C_HOST="\[\033[01;$(_cc_config host 34)m\]"
C_PATH="\[\033[01;$(_cc_config path 33)m\]"
C_GIT="\[\033[01;$(_cc_config git 35)m\]"
C_K8S="\[\033[01;$(_cc_config k8s 36)m\]"
C_RST="\[\033[0m\]"

PS1="${C_USER}\u${C_RST}@${C_HOST}\h${C_RST}:${C_PATH}\w${C_GIT}\$(_git_branch)${C_K8S}\$(_k8s_context)${C_RST}\$ "

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
