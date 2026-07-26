#!/usr/bin/env bash
# CaeliCode WSL — SRE profile tests
set -euo pipefail

# Run base tests first
bash "$(dirname "$0")/test-base.sh" || exit 1

# shellcheck source=test/common.sh
source "$(dirname "$0")/common.sh"

echo "── SRE Profile Tests ──"

# Kubernetes & orchestration
# NOTE: kubectl removed the --short flag in v1.28; plain `version --client`
# prints short-style output on all supported versions.
check_version "kubectl" "kubectl version --client"
check_version "helm" "helm version --short"
check_version "k9s" "k9s version --short"
check_version "argocd" "argocd version --client --short"
check_version "kubectx" "kubectx --version"
check_version "kubens" "kubens --version"
check_version "kustomize" "kustomize version"
check_version "stern" "stern --version"
check_version "flux" "flux --version"

# Infrastructure as Code
check_version "terraform" "terraform --version"
check_version "packer" "packer --version"
check_version "vault" "vault --version"

# Cloud CLIs
check_version "aws" "aws --version"
check_version "eksctl" "eksctl version"
check_version "az (Azure)" "az version"
check_version "gcloud" "gcloud --version"

# Security
check_version "trivy" "trivy --version"

# Profile marker
check "profile marker is sre" grep -qx "sre" /opt/caelicode/PROFILE

summarize "SRE Results"
