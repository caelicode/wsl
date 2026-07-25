#!/usr/bin/env bash
# CaeliCode WSL — Data profile tests
set -euo pipefail

# Run base tests first
bash "$(dirname "$0")/test-base.sh" || exit 1

# shellcheck source=test/common.sh
source "$(dirname "$0")/common.sh"

echo "── Data Profile Tests ──"

# Core data tools
check_version "python3" "python3 --version"
check_version "uv" "uv --version"
check_version "psql" "psql --version"
check_version "sqlite3" "sqlite3 --version"
check_version "duckdb" "duckdb --version"
check_version "dbt" "dbt --version"
check "jupyter-lab installed" command -v jupyter-lab

# Redis client
check_version "redis-cli" "redis-cli --version"

# Profile marker
check "profile marker is data" grep -qx "data" /opt/caelicode/PROFILE

summarize "Data Results"
