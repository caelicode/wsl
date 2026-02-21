# CaeliCode WSL aliases
alias python=python3
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'

# Kubernetes (available in SRE profile)
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kns='kubectl config set-context --current --namespace'
alias kctx='kubectl config use-context'

# Terraform (available in SRE profile)
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'

# Git shortcuts
alias gs='git status'
alias gl='git log --oneline -20'
alias gd='git diff'
alias gco='git checkout'
alias gcm='git commit -m'
