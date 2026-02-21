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

# ── System packages ──────────────────────────────────────────────────
RUN apt-get update -q && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    bash-completion \
    ca-certificates \
    curl \
    dnsutils \
    git \
    gnupg \
    jq \
    nano \
    netcat-openbsd \
    openssh-client \
    socat \
    sudo \
    unzip \
    vim \
    wget \
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

# ── Mise (tool version manager) ─────────────────────────────────────
ENV MISE_DATA_DIR=/opt/mise
ENV XDG_DATA_HOME=/opt/mise
ENV MISE_CONFIG_DIR=/opt/mise/config
ENV PATH="/opt/mise/bin:/opt/mise/shims:$PATH"

RUN install -dm 755 /etc/apt/keyrings && \
    wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | tee /etc/apt/keyrings/mise-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" | tee /etc/apt/sources.list.d/mise.list && \
    apt-get update && apt-get install -y mise && \
    mkdir -p /opt/mise/bin && \
    ln -sf /usr/bin/mise /opt/mise/bin/mise && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Mise: install Python (shared across all profiles) ────────────────
COPY profiles/base.toml /opt/mise/config/config.toml
RUN mise install --env /opt/mise/config/config.toml && mise reshim

# ── SSL/TLS trust ────────────────────────────────────────────────────
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV NODE_OPTIONS=--use-openssl-ca
RUN git config --global http.sslcainfo /etc/ssl/certs/ca-certificates.crt

# ── CaeliCode directory structure ────────────────────────────────────
RUN mkdir -p /opt/caelicode/{scripts,profiles,test} /etc/caelicode

# Copy configs
COPY config/wsl.conf /etc/wsl.conf
COPY config/caelicode.yaml /etc/caelicode/config.yaml
COPY config/.bashrc /etc/skel/.bashrc
COPY config/.bashrc /root/.bashrc
COPY config/.bash_aliases /etc/skel/.bash_aliases
COPY config/.bash_aliases /root/.bash_aliases

# Copy scripts
COPY scripts/ /opt/caelicode/scripts/
RUN chmod +x /opt/caelicode/scripts/*.sh 2>/dev/null || true && \
    chmod +x /opt/caelicode/scripts/caelicode-update && \
    ln -sf /opt/caelicode/scripts/caelicode-update /usr/local/bin/caelicode-update && \
    ln -sf /opt/caelicode/scripts/health-check.sh /usr/local/bin/caelicode-health

# Copy profiles for reference
COPY profiles/ /opt/caelicode/profiles/

# Copy test suite
COPY test/ /opt/caelicode/test/
RUN chmod +x /opt/caelicode/test/*.sh 2>/dev/null || true

# Ensure mise is in PATH for all users
RUN echo 'export PATH="/opt/mise/bin:/opt/mise/shims:$PATH"' >> /etc/skel/.bashrc && \
    echo 'export PATH="/opt/mise/bin:/opt/mise/shims:$PATH"' >> /root/.bashrc

# ── Systemd services ────────────────────────────────────────────────
COPY config/run-once.service /etc/systemd/system/
COPY config/dns-watch.service /etc/systemd/system/
COPY config/dns-watch.timer /etc/systemd/system/
COPY config/ssh-bridge.service /etc/systemd/system/
# Enable services via symlinks (systemctl not available during build)
RUN mkdir -p /etc/systemd/system/multi-user.target.wants && \
    ln -sf /etc/systemd/system/run-once.service /etc/systemd/system/multi-user.target.wants/run-once.service && \
    ln -sf /etc/systemd/system/dns-watch.service /etc/systemd/system/multi-user.target.wants/dns-watch.service && \
    ln -sf /etc/systemd/system/ssh-bridge.service /etc/systemd/system/multi-user.target.wants/ssh-bridge.service

# ── Cleanup ──────────────────────────────────────────────────────────
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

CMD ["/bin/bash"]


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
RUN mise install --env /opt/mise/config/config.toml && mise reshim

ARG VERSION=dev
RUN echo "sre" > /opt/caelicode/PROFILE && \
    echo "${VERSION}" > /opt/caelicode/VERSION


###############################################################################
# DEV — Software development tools
###############################################################################
FROM base AS dev-image

# Podman needs its own apt install
RUN apt-get update -q && apt-get install -y --no-install-recommends \
    podman \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY profiles/dev.toml /opt/mise/config/config.toml
RUN mise install --env /opt/mise/config/config.toml && mise reshim

ARG VERSION=dev
RUN echo "dev" > /opt/caelicode/PROFILE && \
    echo "${VERSION}" > /opt/caelicode/VERSION


###############################################################################
# DATA — Data engineering tools
###############################################################################
FROM base AS data-image

# PostgreSQL client + data dependencies
RUN apt-get update -q && apt-get install -y --no-install-recommends \
    postgresql-client \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY profiles/data.toml /opt/mise/config/config.toml
RUN mise install --env /opt/mise/config/config.toml && mise reshim

# Install Python data tools via uv (after mise installs uv)
ENV UV_TOOL_BIN_DIR=/usr/local/bin
RUN /opt/mise/shims/uv tool install dbt-core --with dbt-postgres

ARG VERSION=dev
RUN echo "data" > /opt/caelicode/PROFILE && \
    echo "${VERSION}" > /opt/caelicode/VERSION
