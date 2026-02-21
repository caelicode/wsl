# Updating

CaeliCode WSL supports in-place updates without re-importing the distro.

## Using `caelicode-update`

### Check for updates

```bash
caelicode-update --dry-run
```

This shows what would change without applying anything.

### Apply update

```bash
caelicode-update
```

This fetches the latest release from GitHub, validates SHA256 checksums, and updates:

- `/opt/caelicode/scripts/` — runtime scripts
- `/opt/caelicode/profiles/` — tool version configs
- `/etc/caelicode/config.yaml` — default config (only if unchanged from default)

It **never** touches your home directory or personal configs.

### Update to a specific version

```bash
caelicode-update --version v1.2.0
```

## What Gets Updated

| Component | Updated | Notes |
|-----------|---------|-------|
| Runtime scripts (DNS, SSH, proxy) | Yes | Replaced in `/opt/caelicode/scripts/` |
| Profile TOML configs | Yes | Tool versions updated |
| Default config.yaml | Only if unmodified | Custom edits are preserved |
| Shell config (.bashrc) | No | User home dir is never touched |
| Installed tools (kubectl, etc.) | No | Run `mise install` after updating profiles |

## Updating Tools After Profile Update

After `caelicode-update` brings new version pins:

```bash
# Re-install tools at new pinned versions
mise install

# Verify
mise list
```

## Full Re-import

For major version bumps or if you want a clean slate:

```powershell
# Export anything you need from the old distro first
wsl --unregister caelicode-sre

# Import the new version
wsl --import caelicode-sre C:\wsl\caelicode caelicode-wsl-sre.tar
```

## Automated Updates via Renovate

If you fork this repo, [Renovate](https://docs.renovatebot.com/) will automatically open PRs when tool versions in `profiles/*.toml` are outdated. Merge the PR to update your build.
