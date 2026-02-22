# CaeliCode WSL — Multi-stage Dockerfile
# Builds profile-specific WSL2 distro images from a shared base layer.
#
# Usage:
#   docker build --target base-image  -t caelicode-wsl:base .
#   docker build --target sre-image   -t caelicode-wsl:sre  .
#   docker build --target dev-image   -t caelicode-wsl:dev  .
#   docker build --target data-image  -t caelicode-wsl:data .
#
# The base stage is cached and reused across all profile builds.

###############################################################################
# BASE — shared foundation for all profiles
###############################################################################
FROM docker.io/ubuntu:24.04 AS base

LABEL maintainer="CaeliCode Solutions <hello@caelicode.com>"
LABEL org.opencontainers.image.source="https://github.com/caelicode/wsl"

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ── System packages ──────────────────────────────────────────────────
# hadolint ignore=DL3008
RUN apt-get update -q && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    bash-completion \
    ca-certificates \
    curl \
    dnsutils \
    git \
    gnupg \
    htop \
    iputils-ping \
    jq \
    locales \
    nano \
    netcat-openbsd \
    openssh-client \
    socat \
    sudo \
    tmux \
    tree \
    unzip \
    vim \
    zip \
    zsh \
    # Python build dependencies
    build-essential \
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    liblzma-dev \
    libncurses5-dev \
    libnss3-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    python3.12-venv \
    zlib1g-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Locale setup ──────────────────────────────────────────────────────
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ── Oh My Zsh (system-wide) ──────────────────────────────────────────
RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /opt/oh-my-zsh && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions /opt/oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting /opt/oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# ── Mise (tool version manager) ─────────────────────────────────────
ENV MISE_DATA_DIR=/opt/mise
ENV XDG_DATA_HOME=/opt/mise
ENV MISE_CONFIG_DIR=/opt/mise/config
# Shims are in PATH during build only (for mise reshim to work).
# At runtime in WSL, shims are NOT in PATH — direct symlinks in
# /opt/mise/bin/ are used instead (see shim bypass step below).
ENV PATH="/opt/mise/bin:/opt/mise/shims:$PATH"

RUN install -dm 755 /etc/apt/keyrings && \
    curl -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" | tee /etc/apt/sources.list.d/mise.list && \
    apt-get update && apt-get install -y --no-install-recommends mise && \
    mkdir -p /opt/mise/bin && \
    ln -sf /usr/bin/mise /opt/mise/bin/mise && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Mise: install base tools (Python + modern CLI essentials) ────────
# Uses BuildKit secret to avoid GitHub API rate limits during install.
# The token is never stored in the image — only used at build time.
COPY profiles/base.toml /opt/mise/config/config.toml
RUN --mount=type=secret,id=github_token \
    GITHUB_TOKEN="$(cat /run/secrets/github_token 2>/dev/null || echo "")" && export GITHUB_TOKEN && \
    mise install --env /opt/mise/config/config.toml && mise reshim

# ── Bypass ALL mise shims ────────────────────────────────────────
# Mise shims hang in WSL (they invoke mise's version resolution which
# attempts network calls and hangs on DNS/timeout). Replace every shim
# with a direct symlink to the real binary in /opt/mise/bin/.
# This runs at build time when mise env vars are available.
RUN for shim in /opt/mise/shims/*; do \
        tool="$(basename "$shim")"; \
        real="$(mise which "$tool" 2>/dev/null)"; \
        if [ -n "$real" ] && [ -x "$real" ]; then \
            ln -sf "$real" "/opt/mise/bin/$tool"; \
        fi; \
    done

# ── Starship prompt (direct install — NOT via mise) ──────────────
# Starship is installed separately because it was removed from the
# mise config to avoid shim issues.
# See: https://starship.rs/guide/#step-1-install-starship
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir /usr/local/bin

# ── SSL/TLS trust ────────────────────────────────────────────────────
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV NODE_OPTIONS=--use-openssl-ca
RUN git config --global http.sslcainfo /etc/ssl/certs/ca-certificates.crt

# ── Starship prompt config ───────────────────────────────────────────
ENV STARSHIP_CONFIG=/etc/caelicode/starship.toml

# ── CaeliCode directory structure ────────────────────────────────────
RUN mkdir -p /opt/caelicode/scripts /opt/caelicode/profiles /opt/caelicode/test /etc/caelicode

# Copy configs
COPY config/wsl.conf /etc/wsl.conf
COPY config/caelicode.yaml /etc/caelicode/config.yaml
COPY config/starship.toml /etc/caelicode/starship.toml
COPY config/.bashrc /etc/skel/.bashrc
COPY config/.bashrc /root/.bashrc
COPY config/.bash_aliases /etc/skel/.bash_aliases
COPY config/.bash_aliases /root/.bash_aliases
COPY config/.zshrc /etc/skel/.zshrc
COPY config/.zshrc /root/.zshrc

# Copy scripts
COPY scripts/ /opt/caelicode/scripts/
RUN find /opt/caelicode/scripts -name "*.sh" -exec chmod +x {} + && \
    chmod +x /opt/caelicode/scripts/caelicode-update && \
    ln -sf /opt/caelicode/scripts/caelicode-update /usr/local/bin/caelicode-update && \
    ln -sf /opt/caelicode/scripts/health-check.sh /usr/local/bin/caelicode-health

# Copy profiles for reference
COPY profiles/ /opt/caelicode/profiles/

# Copy test suite
COPY test/ /opt/caelicode/test/
RUN find /opt/caelicode/test -name "*.sh" -exec chmod +x {} +

# ── Default shell: zsh ───────────────────────────────────────────────
RUN chsh -s /bin/zsh root && \
    { sed -i 's|SHELL=/bin/bash|SHELL=/bin/zsh|' /etc/default/useradd 2>/dev/null || true; }

# ── Default user ─────────────────────────────────────────────────────
# Pre-create a default user during build so the distro is immediately
# usable after `wsl --import` — no boot-time Windows interop needed.
# Users can rename later via: sudo usermod -l newname caelicode
RUN useradd -ms /bin/zsh caelicode && \
    usermod -aG sudo caelicode && \
    echo "caelicode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/caelicode && \
    chmod 0440 /etc/sudoers.d/caelicode && \
    cp /etc/skel/.bashrc /etc/skel/.bash_aliases /etc/skel/.zshrc /home/caelicode/ && \
    chown caelicode:caelicode /home/caelicode/.bashrc /home/caelicode/.bash_aliases /home/caelicode/.zshrc

# ── Persist environment for WSL ──────────────────────────────────────
# Docker ENV is lost on `docker export` → `wsl --import`. Write PATH and
# other critical vars to /etc/environment (read by WSL on boot) and
# /etc/profile.d/ (sourced by login shells) so tools are always available.
RUN echo 'PATH="/opt/mise/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > /etc/environment && \
    echo 'MISE_DATA_DIR="/opt/mise"' >> /etc/environment && \
    echo 'MISE_CONFIG_DIR="/opt/mise/config"' >> /etc/environment && \
    echo 'STARSHIP_CONFIG="/etc/caelicode/starship.toml"' >> /etc/environment
COPY config/caelicode-env.sh /etc/profile.d/00-caelicode-env.sh

# ── Cleanup ──────────────────────────────────────────────────────────
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

CMD ["/bin/zsh"]


###############################################################################
# BASE IMAGE — minimal profile (just the foundation)
###############################################################################
FROM base AS base-image

ARG VERSION=dev
RUN echo "base" > /opt/caelicode/PROFILE && \
    echo "${VERSION}" > /opt/caelicode/VERSION


###############################################################################
# SRE — Platform engineering & Kubernetes tools
###############################################################################
FROM base AS sre-image

COPY profiles/sre.toml /opt/mise/config/config.toml
RUN --mount=type=secret,id=github_token \
    GITHUB_TOKEN="$(cat /run/secrets/github_token 2>/dev/null || echo "")" && export GITHUB_TOKEN && \
    mise install --env /opt/mise/config/config.toml && mise reshim

# Bypass mise shims for profile-specific tools
RUN for shim in /opt/mise/shims/*; do \
        tool="$(basename "$shim")"; \
        real="$(mise which "$tool" 2>/dev/null)"; \
        if [ -n "$real" ] && [ -x "$real" ] && [ ! -e "/opt/mise/bin/$tool" ]; then \
            ln -sf "$real" "/opt/mise/bin/$tool"; \
        fi; \
    done

# Azure CLI (official Microsoft apt repository)
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Google Cloud SDK
RUN curl -sSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
        gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
        tee /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update -q && apt-get install -y --no-install-recommends google-cloud-cli && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG VERSION=dev
RUN echo "sre" > /opt/caelicode/PROFILE && \
    echo "${VERSION}" > /opt/caelicode/VERSION


###############################################################################
# DEV — Software development tools
###############################################################################
FROM base AS dev-image

# Container tools
RUN apt-get update -q && apt-get install -y --no-install-recommends \
    podman \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY profiles/dev.toml /opt/mise/config/config.toml
RUN --mount=type=secret,id=github_token \
    GITHUB_TOKEN="$(cat /run/secrets/github_token 2>/dev/null || echo "")" && export GITHUB_TOKEN && \
    mise install --env /opt/mise/config/config.toml && mise reshim

# Bypass mise shims for profile-specific tools
RUN for shim in /opt/mise/shims/*; do \
        tool="$(basename "$shim")"; \
        real="$(mise which "$tool" 2>/dev/null)"; \
        if [ -n "$real" ] && [ -x "$real" ] && [ ! -e "/opt/mise/bin/$tool" ]; then \
            ln -sf "$real" "/opt/mise/bin/$tool"; \
        fi; \
    done

ARG VERSION=dev
RUN echo "dev" > /opt/caelicode/PROFILE && \
    echo "${VERSION}" > /opt/caelicode/VERSION


###############################################################################
# DATA — Data engineering tools
###############################################################################
FROM base AS data-image

# PostgreSQL client + Redis client + SQLite
RUN apt-get update -q && apt-get install -y --no-install-recommends \
    postgresql-client \
    redis-tools \
    sqlite3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY profiles/data.toml /opt/mise/config/config.toml
RUN --mount=type=secret,id=github_token \
    GITHUB_TOKEN="$(cat /run/secrets/github_token 2>/dev/null || echo "")" && export GITHUB_TOKEN && \
    mise install --env /opt/mise/config/config.toml && mise reshim

# Bypass mise shims for profile-specific tools
RUN for shim in /opt/mise/shims/*; do \
        tool="$(basename "$shim")"; \
        real="$(mise which "$tool" 2>/dev/null)"; \
        if [ -n "$real" ] && [ -x "$real" ] && [ ! -e "/opt/mise/bin/$tool" ]; then \
            ln -sf "$real" "/opt/mise/bin/$tool"; \
        fi; \
    done

# Install Python data tools via uv (after mise installs uv)
ENV UV_TOOL_BIN_DIR=/usr/local/bin
RUN /opt/mise/bin/uv tool install dbt-core --with dbt-postgres && \
    /opt/mise/bin/uv tool install jupyterlab

ARG VERSION=dev
RUN echo "data" > /opt/caelicode/PROFILE && \
    echo "${VERSION}" > /opt/caelicode/VERSION
