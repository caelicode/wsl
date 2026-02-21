#!/usr/bin/env bash
# CaeliCode WSL — Build script
# Builds a WSL2-importable tar from the multi-stage Dockerfile.
#
# Usage:
#   ./build.sh                          # Build base profile
#   ./build.sh --profile sre            # Build SRE profile
#   ./build.sh --profile dev --tag v1   # Build Dev profile with version tag
#   ./build.sh --all                    # Build all profiles

set -euo pipefail

PROFILE="base"
VERSION="dev"
BUILD_ALL=false
TAR_DIR="$PWD/images"
RUNTIME="podman"

# Detect container runtime
if command -v podman &>/dev/null; then
    RUNTIME="podman"
elif command -v docker &>/dev/null; then
    RUNTIME="docker"
else
    echo "ERROR: Neither podman nor docker found. Please install one."
    exit 1
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)  PROFILE="$2"; shift 2 ;;
        --tag)      VERSION="$2"; shift 2 ;;
        --all)      BUILD_ALL=true; shift ;;
        -h|--help)
            echo "Usage: ./build.sh [--profile base|sre|dev|data] [--tag VERSION] [--all]"
            echo ""
            echo "Options:"
            echo "  --profile   Profile to build (default: base)"
            echo "  --tag       Version tag (default: dev)"
            echo "  --all       Build all profiles"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

build_profile() {
    local profile="$1"
    local image_name="caelicode-wsl-${profile}"
    local target="${profile}-image"

    echo "══════════════════════════════════════════════"
    echo "Building: ${image_name} (target: ${target})"
    echo "══════════════════════════════════════════════"

    $RUNTIME build \
        --target "$target" \
        --build-arg "VERSION=${VERSION}" \
        -t "${image_name}:${VERSION}" \
        -t "${image_name}:latest" \
        .

    # Export to tar
    mkdir -p "$TAR_DIR"
    local tar_name="${image_name}.tar"

    echo "Exporting ${image_name} → ${TAR_DIR}/${tar_name}"
    local container_id
    container_id=$($RUNTIME run --privileged -dt "${image_name}:${VERSION}" bash)
    $RUNTIME export "$container_id" > "${TAR_DIR}/${tar_name}"
    $RUNTIME rm -f "$container_id" >/dev/null 2>&1

    # Generate checksum
    (cd "$TAR_DIR" && sha256sum "$tar_name" >> checksums.txt)

    local size
    size=$(du -h "${TAR_DIR}/${tar_name}" | cut -f1)
    echo "Built: ${TAR_DIR}/${tar_name} (${size})"
    echo ""
}

# Clear previous checksums
mkdir -p "$TAR_DIR"
: > "${TAR_DIR}/checksums.txt"

if $BUILD_ALL; then
    for p in base sre dev data; do
        build_profile "$p"
    done
    echo "All profiles built. Checksums:"
    cat "${TAR_DIR}/checksums.txt"
else
    build_profile "$PROFILE"
fi

# Generate SBOM (simple tool manifest)
echo "Generating SBOM..."
SBOM_FILE="${TAR_DIR}/sbom.json"
python3 -c "
import json, tomllib, pathlib

sbom = {'version': '${VERSION}', 'profiles': {}}
for toml_file in sorted(pathlib.Path('profiles').glob('*.toml')):
    with open(toml_file, 'rb') as f:
        data = tomllib.load(f)
    profile_name = toml_file.stem
    sbom['profiles'][profile_name] = data.get('tools', {})

print(json.dumps(sbom, indent=2))
" > "$SBOM_FILE"

echo "SBOM: ${SBOM_FILE}"
echo "Done!"
