# ~/.bashrc: CaeliCode WSL shell initialization

# If not running interactively, don't do anything
[ -z "${PS1:-}" ] && return

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

# ── PATH ─────────────────────────────────────────────────────────────
# NO mise shims — all tools are symlinked into /opt/mise/bin/ at build time.
export PATH="/opt/mise/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ── SSL/TLS ──────────────────────────────────────────────────────────
# Kept in sync with .zshrc so bash and zsh behave identically behind
# corporate MITM proxies.
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export NODE_OPTIONS=--use-openssl-ca

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
        if [[ -x /opt/mise/bin/kubectl ]]; then
            local ctx
            ctx=$(/opt/mise/bin/kubectl config current-context 2>/dev/null)
            [ -n "$ctx" ] && echo " ⎈${ctx}"
        fi
    }

    PS1="\[\033[01;32m\]\u\[\033[0m\]@\[\033[01;34m\]\h\[\033[0m\]:\[\033[01;33m\]\w\[\033[01;35m\]\$(_git_branch)\[\033[01;36m\]\$(_k8s_context)\[\033[0m\]\$ "
fi

# ── Zoxide (smart cd) ────────────────────────────────────────────────
if [[ -x /opt/mise/bin/zoxide ]]; then
    eval "$(/opt/mise/bin/zoxide init bash)"
fi

# ── Direnv ────────────────────────────────────────────────────────────
if [[ -x /opt/mise/bin/direnv ]]; then
    eval "$(/opt/mise/bin/direnv hook bash)"
fi

# ── FZF Integration ──────────────────────────────────────────────────
if [[ -x /opt/mise/bin/fzf ]]; then
    eval "$(/opt/mise/bin/fzf --bash 2>/dev/null)" || true
fi

# ── SSH agent bridge socket ──────────────────────────────────────────
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    for _cc_sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/caelicode-ssh-agent.sock" /tmp/caelicode-ssh-agent.sock; do
        if [ -S "$_cc_sock" ]; then export SSH_AUTH_SOCK="$_cc_sock"; break; fi
    done
    unset _cc_sock
fi

# ── CaeliCode MOTD, update notice & runtime init ─────────────────────
if [ -r /opt/caelicode/current/scripts/caelicode-motd.sh ]; then
    . /opt/caelicode/current/scripts/caelicode-motd.sh
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
if [[ -x /opt/mise/bin/kubectl ]]; then
    source <(/opt/mise/bin/kubectl completion bash 2>/dev/null)
    complete -o default -F __start_kubectl k
fi

# Helm completion (SRE profile)
if [[ -x /opt/mise/bin/helm ]]; then
    source <(/opt/mise/bin/helm completion bash 2>/dev/null)
fi
