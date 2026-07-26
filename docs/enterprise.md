# Enterprise & Team Features

## Team profile layers

Give a whole team extra tools without forking this repo. A **layer**
is a TOML file containing only a `[tools]` table of exact pins:

```toml
# team-data-platform.toml
[tools]
"dbt-core" = "1.9.4"
sqlfluff = "3.3.1"
```

Host it anywhere HTTPS-reachable (an internal Git repo raw URL works),
then on each machine:

```bash
caelicode-profile add data-platform https://git.corp.example.com/platform/tools.toml
```

The layer is validated (only `[tools]` with string pins is accepted),
its contents are shown for confirmation, and the tools are installed
immediately. Layers live in `/etc/caelicode/profiles.d/` and are
merged over the built-in profile in filename order — later layers win.

```bash
caelicode-profile list      # what's layered
caelicode-profile sync      # re-merge + reinstall (e.g. after editing a layer)
caelicode-profile remove data-platform
```

`caelicode-update` re-merges layers over each new release's base
profile automatically, so updates never drop your team's tools.

## Fleet policy

Provision `/etc/caelicode/policy.yaml` (via your MDM/config tooling)
to manage updates centrally:

```yaml
policy:
  # Hold every machine at a specific release. caelicode-update moves
  # machines to the pin (up or down) and refuses other targets.
  pin_version: v0.11.0

  # Or: block self-service updates entirely (central rollout only).
  updates_disabled: false

  # Serve releases from your fork instead of caelicode/wsl —
  # air-gapped mirrors and internal patch releases work unchanged.
  update_repo: my-org/wsl
```

The daily check, login notice, and `caelicode-update` all honor the
policy. `caelicode-update --check` keeps its exit-code contract
(0/10/20/1) relative to the pinned version, so your existing
monitoring can watch fleet drift.

## Windows toast notifications

Opt-in OS-level update notifications (once per new release, per user):

```yaml
# /etc/caelicode/config.yaml
updates:
  notify_windows_toast: true
```

Toasts fire from the first WSL shell of a boot (Windows interop is
needed to raise them); the login banner remains the primary channel.

## Release integrity for auditors

Every release ships:

- `caelicode-manifest.json` — per-profile image SHA256s + the payload
  checksum the in-place updater verifies
- `sbom.json` — CycloneDX inventory generated from the **tested**
  images (resolved tool versions and apt packages, not manifests)
- `checksums.txt` — flat SHA256 list

Published images are byte-identical to the images CI tested — the
release pipeline promotes artifacts, it never rebuilds them.

## Devcontainer parity

The same Dockerfile that produces the WSL images powers a
devcontainer, so local WSL and cloud/container dev environments can't
drift:

```jsonc
// .devcontainer/devcontainer.json (shipped in this repo)
{ "build": { "dockerfile": "../Dockerfile", "target": "dev-image" } }
```

Open the repo in VS Code → "Reopen in Container", or point Codespaces
at it. Swap `target` for `sre-image`/`data-image` to match your
profile.
