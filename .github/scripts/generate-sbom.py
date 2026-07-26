#!/usr/bin/env python3
"""CaeliCode WSL — CycloneDX SBOM from *resolved* image contents.

Earlier SBOMs copied profiles/*.toml verbatim, recording the literal
string "latest" for ~40 tools and omitting every apt package. This one
consumes listings captured from the images that were actually tested:

  toolinfo/mise-<profile>.json   `mise ls --current --json` output
  toolinfo/dpkg-<profile>.tsv    `dpkg-query -W` package\tversion lines

Every component records which profile images contain it via the
CycloneDX `group` field (kept compact: comma-joined profile list).
"""

import argparse
import json
import pathlib
import sys


def load_mise(path: pathlib.Path) -> dict[str, str]:
    """tool -> resolved version from `mise ls --current --json`."""
    tools: dict[str, str] = {}
    try:
        data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
        return tools
    if not isinstance(data, dict):
        return tools
    for tool, entries in data.items():
        if isinstance(entries, list):
            for entry in entries:
                version = (entry or {}).get("version")
                if version:
                    tools[tool] = str(version)
                    break
        elif isinstance(entries, dict) and entries.get("version"):
            tools[tool] = str(entries["version"])
    return tools


def load_dpkg(path: pathlib.Path) -> dict[str, str]:
    pkgs: dict[str, str] = {}
    try:
        for line in path.read_text().splitlines():
            parts = line.split("\t")
            if len(parts) == 2 and parts[0]:
                pkgs[parts[0]] = parts[1]
    except OSError:
        pass
    return pkgs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True, help="release tag (vX.Y.Z)")
    ap.add_argument("--toolinfo", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    args = ap.parse_args()

    # component key -> {"name","version","type","purl"|None,"profiles":set()}
    components: dict[tuple, dict] = {}

    def add(name: str, version: str, ctype: str, purl: str | None, profile: str):
        key = (ctype, name, version)
        comp = components.setdefault(
            key,
            {"name": name, "version": version, "type": ctype, "purl": purl, "profiles": set()},
        )
        comp["profiles"].add(profile)

    profiles_seen = []
    for mise_file in sorted(args.toolinfo.glob("mise-*.json")):
        profile = mise_file.stem.replace("mise-", "")
        profiles_seen.append(profile)
        for tool, version in load_mise(mise_file).items():
            add(tool, version, "application", f"pkg:generic/{tool}@{version}", profile)
        dpkg_file = args.toolinfo / f"dpkg-{profile}.tsv"
        for pkg, version in load_dpkg(dpkg_file).items():
            add(pkg, version, "library", f"pkg:deb/ubuntu/{pkg}@{version}?arch=amd64", profile)

    if not components:
        print("::error::no tool listings found — SBOM would be empty", file=sys.stderr)
        return 1

    sbom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        # CycloneDX `version` is the BOM document revision (an integer),
        # not the software release — that lives on metadata.component.
        "version": 1,
        "metadata": {
            "component": {
                "type": "operating-system",
                "name": "caelicode-wsl",
                "version": args.version,
                "description": f"CaeliCode WSL2 distro images ({', '.join(profiles_seen)})",
            }
        },
        "components": [
            {
                "type": comp["type"],
                "name": comp["name"],
                "version": comp["version"],
                **({"purl": comp["purl"]} if comp["purl"] else {}),
                "group": ",".join(sorted(comp["profiles"])),
            }
            for comp in sorted(components.values(), key=lambda c: (c["type"], c["name"]))
        ],
    }

    args.out.write_text(json.dumps(sbom, indent=2) + "\n")
    print(f"[generate-sbom] {len(sbom['components'])} components across {len(profiles_seen)} profiles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
