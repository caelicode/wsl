# CaeliCode WSL aliases

# ── Modern CLI replacements (graceful fallback) ────────────────────
if command -v eza &>/dev/null; then
    alias ls='eza --icons'
    alias ll='eza -alF --icons'
    alias la='eza -a --icons'
    alias l='eza -F --icons'
    alias tree='eza --tree --icons'
else
    alias ll='ls -alF --color=auto'
    alias la='ls -A --color=auto'
    alias l='ls -CF --color=auto'
fi

if command -v bat &>/dev/null; then
    alias cat='bat --paging=never --style=plain'
    alias bcat='bat'
fi

# ── General ────────────────────────────────────────────────────────
alias python=python3
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# ── Git shortcuts ──────────────────────────────────────────────────
alias gs='git status'
alias gl='git log --oneline -20'
alias gd='git diff'
alias gco='git checkout'
alias gcm='git commit -m'
command -v lazygit &>/dev/null && alias lg='lazygit'

# ── Kubernetes (SRE profile) ──────────────────────────────────────
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
command -v kubens &>/dev/null && alias kns='kubens'
command -v kubectx &>/dev/null && alias kctx='kubectx'

# ── Terraform (SRE profile) ───────────────────────────────────────
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'

# ── Cloud CLIs ─────────────────────────────────────────────────────
command -v aws &>/dev/null && alias awsid='aws sts get-caller-identity'
