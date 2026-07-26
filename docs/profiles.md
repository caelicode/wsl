# Profiles

CaeliCode WSL uses a profile-based architecture. Each profile builds on the shared **base** layer and adds tools specific to a role.

All tool versions are pinned exactly in `profiles/*.toml` — check any
release's `sbom.json` asset for the complete resolved inventory
(including apt packages) of the images you are running.

## Base

The foundation layer included in every profile.

**System packages:** bash-completion, ca-certificates, curl, dnsutils, git, gnupg, htop, jq, nano, netcat, openssh-client, socat, sudo, tmux, tree, unzip, vim, wget, zip, zsh

**Managed tools (via mise):** Python 3.12, gh, fzf, ripgrep, fd, bat, eza, delta, direnv, zoxide, yq

**CaeliCode features:** In-place updates with rollback, update notifications, SSH agent bridge, Windows proxy detection, health check, prompt themes, configurable MOTD.

## SRE

For platform engineers, DevOps, and infrastructure teams.

Everything in base, plus (versions as currently pinned in `profiles/sre.toml`):

| Tool | Purpose |
|------|---------|
| kubectl, helm, k9s | Kubernetes CLI, package manager, TUI dashboard |
| argocd, flux2 | GitOps continuous delivery |
| kubectx/kubens, kustomize, stern | Context switching, manifests, log tailing |
| terraform, packer, vault | Infrastructure as code & secrets |
| AWS CLI, Azure CLI, Google Cloud SDK, eksctl | Cloud CLIs |
| trivy | Container/security scanner |

**Shell aliases:** `k` → kubectl, `kgp` → kubectl get pods, `kgs` → kubectl get svc, `tf` → terraform, `tfi` → terraform init, `tfp` → terraform plan, `tfa` → terraform apply (aliases only activate when the tool is present)

## Dev

For software developers working across multiple languages.

Everything in base, plus:

| Tool | Purpose |
|------|---------|
| Node.js, Go, Rust, Java (Temurin 21), Bun | Language runtimes |
| uv | Fast Python package manager |
| Podman | Rootless container runtime (apt package) |
| lazygit, shellcheck, hadolint | Developer tooling |

**Note:** Podman is installed via apt (system package) rather than mise, providing rootless container support inside WSL.

## Data

For data engineers, analysts, and ML practitioners.

Everything in base, plus:

| Tool | Purpose |
|------|---------|
| uv | Fast Python package manager |
| dbt-core + dbt-postgres | Data transformation framework |
| DuckDB | In-process analytics database |
| JupyterLab | Notebooks |
| PostgreSQL client, Redis client, SQLite | Database clients (apt packages) |

## Version Pinning

Every mise-managed tool is pinned to an exact version in
`profiles/*.toml`, each carrying a `# renovate:` annotation.
[Renovate](https://docs.renovatebot.com/) opens PRs when new versions
ship; CI rebuilds and tests all four profiles before a bump can merge,
so you get updates without losing reproducibility.

To check which versions are installed:

```bash
mise list
```

## Custom Profiles

To create a custom profile:

1. Create a new `profiles/custom.toml` with your tool versions
2. Add a new stage in the `Dockerfile` following the existing pattern
3. Build with `./build.sh --profile custom`
