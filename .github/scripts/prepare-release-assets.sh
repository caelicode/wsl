#!/usr/bin/env bash
# CaeliCode WSL — release asset preparation
# Runs as the semantic-release `prepare` step (@semantic-release/exec),
# i.e. AFTER the next version is decided but BEFORE the tag is pushed
# or the release is created — failing here aborts the release cleanly.
#
# Usage: prepare-release-assets.sh <version-without-v>
#
# Inputs (from the workflow):
#   dist/                      tested image tars + .sha256 (promoted from
#                              the build job — never rebuilt)
#   dist/toolinfo/             resolved tool listings captured from the
#                              tested images (mise ls / dpkg)
#   PREDICTED_VERSION (env)    version the images were stamped with
#
# Outputs (added to dist/ and uploaded by @semantic-release/github):
#   caelicode-update-payload.tar.gz   in-place update payload
#   caelicode-manifest.json           version, payload sha256, reimport flag
#   checksums.txt, sbom.json, RELEASE_VERSION

set -euo pipefail

VERSION="${1:?usage: prepare-release-assets.sh <version>}"
DIST="dist"
REPO_SLUG="${GITHUB_REPOSITORY:-caelicode/wsl}"

log() { echo "[prepare-release] $*"; }

# ── Guard: the images we are about to publish must carry this version ─
# The build job stamps images with the version predicted by a
# semantic-release dry run. If prediction and reality ever diverge
# (e.g. a manual tag pushed in between), abort BEFORE tagging.
if [ -n "${PREDICTED_VERSION:-}" ] && [ "${PREDICTED_VERSION}" != "v${VERSION}" ]; then
    echo "::error::Predicted version ${PREDICTED_VERSION} != released version v${VERSION}; aborting release." >&2
    exit 1
fi

# ── Guard: every profile image must be present ───────────────────────
for profile in base sre dev data; do
    if [ ! -f "${DIST}/caelicode-wsl-${profile}.tar.gz" ] || [ ! -f "${DIST}/caelicode-wsl-${profile}.sha256" ]; then
        echo "::error::Missing tested artifact for profile '${profile}' — refusing to release." >&2
        exit 1
    fi
done
log "All four tested profile images present"

# ── Update payload (what caelicode-update applies in place) ──────────
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "${STAGE}/skel" "${STAGE}/themes" "${STAGE}/systemd"
cp -a scripts  "${STAGE}/scripts"
cp -a profiles "${STAGE}/profiles"
cp -a config/themes/. "${STAGE}/themes/"
# The default theme IS the shipped starship.toml — same rule as the Dockerfile.
cp config/starship.toml "${STAGE}/themes/default.toml"
for f in .bashrc .bash_aliases .zshrc; do
    cp "config/${f}" "${STAGE}/skel/${f}"
done
cp -a config/systemd/. "${STAGE}/systemd/"

tar czf "${DIST}/caelicode-update-payload.tar.gz" -C "$STAGE" scripts profiles themes skel systemd
PAYLOAD_SHA256="$(sha256sum "${DIST}/caelicode-update-payload.tar.gz" | cut -d' ' -f1)"
log "Payload built (sha256 ${PAYLOAD_SHA256:0:16}…)"

# ── Release manifest ─────────────────────────────────────────────────
# A release that ships new apt packages / OS-level changes cannot be
# fully applied in place. Maintainers signal that by committing a
# `.reimport-required` file at the repo root for that release (and
# removing it afterwards); the updater and installers read this flag
# from the manifest.
REQUIRES_REIMPORT=false
[ -f .reimport-required ] && REQUIRES_REIMPORT=true

python3 - "$VERSION" "$PAYLOAD_SHA256" "$REQUIRES_REIMPORT" "$REPO_SLUG" <<'PY'
import json, sys, pathlib
version, payload_sha, reimport, repo = sys.argv[1:5]
profiles = {}
for sha_file in sorted(pathlib.Path("dist").glob("caelicode-wsl-*.sha256")):
    profile = sha_file.stem.replace("caelicode-wsl-", "")
    digest = sha_file.read_text().split()[0]
    tar = pathlib.Path("dist") / f"caelicode-wsl-{profile}.tar.gz"
    profiles[profile] = {"sha256": digest, "size": tar.stat().st_size}
manifest = {
    "version": f"v{version}",
    "payload_sha256": payload_sha,
    "requires_reimport": reimport == "true",
    "notes_url": f"https://github.com/{repo}/releases/tag/v{version}",
    "profiles": profiles,
}
pathlib.Path("dist/caelicode-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY
log "Manifest written (requires_reimport=${REQUIRES_REIMPORT})"

# ── Checksums + SBOM ────────────────────────────────────────────────
(cd "$DIST" && cat ./*.sha256 > checksums.txt)
python3 .github/scripts/generate-sbom.py --version "v${VERSION}" \
    --toolinfo "${DIST}/toolinfo" --out "${DIST}/sbom.json"
log "SBOM generated from resolved image contents"

# Consumed by the publish-draft step after semantic-release finishes.
printf '%s\n' "$VERSION" > "${DIST}/RELEASE_VERSION"
log "Release v${VERSION} prepared"
