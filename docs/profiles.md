# Profiles

CaeliCode WSL uses a profile-based architecture. Each profile builds on the shared **base** layer and adds tools specific to a role.

## Base

The foundation layer included in every profile.

**System packages:** bash-completion, ca-certificates, curl, dnsutils, git, gnupg, jq, nano, openssh-client, socat, sudo, unzip, vim, wget

**Managed tools (via mise):** Python 3.12

**CaeliCode features:** Dynamic DNS, SSH agent bridge, proxy detection, health check, in-place updates, configurable MOTD and PS1.

## SRE

For platform engineers, DevOps, and infrastructure teams.

Everything in base, plus:

| Tool | Version | Purpose |
|------|---------|---------|
| kubectl | 1.35.1 | Kubernetes CLI |
| helm | 4.1.1 | Kubernetes package manager |
| terraform | 1.14.5 | Infrastructure as code |
| k9s | 0.50.18 | Kubernetes TUI dashboard |
| argocd | 3.3.1 | GitOps continuous delivery |
| trivy | 0.60.0 | Container security scanner |

**Shell aliases:** `k` → kubectl, `kgp` → kubectl get pods, `kgs` → kubectl get svc, `tf` → terraform, `tfi` → terraform init, `tfp` → terraform plan, `tfa` → terraform apply

## Dev

For software developers working across multiple languages.

Everything in base, plus:

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | 24.13.1 | JavaScript/TypeScript runtime |
| Go | 1.26.0 | Go programming language |
| Rust | 1.93.1 | Rust programming language |
| uv | 0.6.3 | Fast Python package manager |
| Podman | system | Rootless container runtime |

**Note:** Podman is installed via apt (system package) rather than mise, providing rootless container support inside WSL.

## Data

For data engineers, analysts, and ML practitioners.

Everything in base, plus:

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.12.9 | Primary language |
| uv | 0.6.3 | Fast Python package manager |
| dbt-core | latest | Data transformation framework |
| dbt-postgres | latest | PostgreSQL adapter for dbt |
| PostgreSQL client | system | psql, pg_dump, etc. |

## Version Pinning

All tool versions are pinned in `profiles/*.toml` files. Renovate automatically opens PRs when new versions are available, so you get updates without losing reproducibility.

To check which versions are installed:

```bash
mise list
```

## Custom Profiles

To create a custom profile:

1. Create a new `profiles/custom.toml` with your tool versions
2. Add a new stage in the `Dockerfile` following the existing pattern
3. Build with `./build.sh --profile custom`
