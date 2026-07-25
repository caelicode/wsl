# Updating

CaeliCode WSL ships a staged, checksum-verified in-place updater with
automatic update notifications. Your home directory and personal
dotfiles are never touched by any update path.

## How you learn an update exists

A systemd timer (`caelicode-update-check.timer`) runs a background
check once a day (with a randomized delay) and caches the result in
`/var/lib/caelicode/update-state.json`. When a newer release exists,
your login banner shows:

```
⬆ Update available: v0.10.2 → v0.11.0
  Run: caelicode-update
```

The banner reads **only the local cache** — shell startup never makes
a network call. `caelicode-health` shows the same information.

Both behaviors are configurable in `/etc/caelicode/config.yaml`:

```yaml
updates:
  check_enabled: true   # daily background check
  notify_motd: true     # login notice
```

## Checking manually

```bash
caelicode-update --check
```

Exit codes are script-friendly:

| Exit | Meaning |
|------|---------|
| 0 | Up to date |
| 10 | Update available (in-place) |
| 20 | Update available (requires full re-import) |
| 1 | Check failed (offline, rate-limited) |

## Applying an update

```bash
# Preview what would change
caelicode-update --dry-run

# Apply
caelicode-update
```

The updater:

1. Downloads the release's update payload and **verifies its SHA256**
   against the release manifest (`caelicode-manifest.json`).
2. Stages it under `/opt/caelicode/releases/<version>/` — nothing
   visible changes yet.
3. Updates `/etc/skel` templates, systemd units, and tool versions
   (`mise install` + regeneration of the `/opt/mise/bin` symlinks the
   runtime PATH uses).
4. Activates atomically by flipping the `/opt/caelicode/current`
   symlink and recording the version.

A failure before activation leaves the running release untouched.

## Rollback

The previous release is kept on disk:

```bash
caelicode-update --rollback
```

This flips `current` back, restores the previous tool pins, and keeps
the release you rolled back from so you can move forward again.

## Pinning a specific version

```bash
caelicode-update --version           # show installed version
caelicode-update --version v0.10.2   # update or downgrade to a tag
```

Without an explicit tag the updater never downgrades, even if the
latest release is withdrawn.

## What gets updated

| Component | Updated | Notes |
|-----------|---------|-------|
| Runtime scripts | Yes | Staged under `releases/<version>/scripts` |
| Tool version pins | Yes | `mise install` runs and PATH symlinks are regenerated |
| Starship themes | Yes | Your **active** prompt updates too, if it matches a shipped theme; customized prompts are never touched |
| `/etc/skel` shell templates | Yes | For new users only |
| systemd units | Yes | Update-check timer definitions |
| `/etc/caelicode/config.yaml` | No | Your settings are preserved |
| Your home directory | **Never** | |
| apt packages / OS changes | No | Requires a full re-import (below) |

## Major upgrades (full re-import)

Releases that change apt packages or the OS layer are flagged
`requires_reimport` in their manifest. For those, `--check` exits 20,
the login notice says so, and a plain `caelicode-update` refuses with
guidance instead of half-applying.

```bash
caelicode-update --full
```

prints the step-by-step guide: back up (there's a helper —
`tools/caelicode-backup.ps1`), unregister, re-import, restore. From
PowerShell you can do the same with an automatic backup:

```powershell
.\install.ps1 -Profile sre -Upgrade
```

which exports the existing distro to `%USERPROFILE%\caelicode-backups\`
(and aborts if the backup fails) before reinstalling.

## Managed fleets

Machines provisioned with `/etc/caelicode/policy.yaml` can pin a
version, disable self-service updates, or pull releases from an
internal fork — see [Enterprise & Team Features](enterprise.md).
Team tool layers added with `caelicode-profile` are re-merged
automatically on every update.

## For maintainers: marking a release as re-import-only

Commit a `.reimport-required` file at the repo root before the release
lands (and remove it afterwards). The release workflow copies the flag
into `caelicode-manifest.json`, which the updater and notifications
honor.

## Automated version bumps via Renovate

Tool pins in `profiles/*.toml` carry `# renovate:` annotations;
[Renovate](https://docs.renovatebot.com/) opens grouped PRs when new
tool versions ship, and CI fully builds and tests every bump before it
can merge.
