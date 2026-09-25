#!/usr/bin/env python3
"""
Scrape installed EPICS support module versions and Python package versions
into a single JSON manifest, for publishing alongside the IOC schema on
each tagged GitHub Release.
"""
import json
import pathlib
import subprocess
import sys
from datetime import datetime, timezone

# use ruamel.yaml from ibek
from ruamel.yaml import YAML
from ruamel.yaml.error import YAMLError

IBEK_SUPPORT_ROOT = pathlib.Path("/epics/generic-source/ibek-support")
OUTPUT_PATH = pathlib.Path("/epics/versions.json")

_yaml = YAML(typ="safe")

# mirrors the default in ibek-support's _ansible/roles/support/vars/main.yml:
#   organization: https://github.com/epics-modules
DEFAULT_ORGANIZATION = "https://github.com/epics-modules"

##########


def _looks_like_commit_sha(version: str) -> bool:
    """full or short git commit SHAs are 7-40 lowercase hex chars."""
    return 7 <= len(version) <= 40 and all(c in "0123456789abcdef" for c in version.lower())


def get_epics_modules(root: pathlib.Path) -> dict:

    modules = {}

    # look though all install.yml files in ibek-support built in the dependency tree
    for filepath in sorted(root.rglob("*.install.yml")):

        try:
            data = _yaml.load(filepath.read_text())

        except YAMLError as e:
            print(f"warning: could not parse {filepath}: {e}", file=sys.stderr)
            continue

        if not data:
            continue

        name = data.get("module") or filepath.stem.replace(".install", "")
        version = str(data.get("version", "unknown"))
        organization = data.get("organization", DEFAULT_ORGANIZATION)
        git_repo = data.get("git_repo") or f"{organization.rstrip('/')}/{name}"

        modules[name] = {
            "version": version,
            "organization": organization,
            "git-repo": git_repo,
            "pinned-to-commit": _looks_like_commit_sha(version), # identify when pinned to a commit and not an actual release
        }

    return modules


def get_python_packages() -> dict:

    # explicitly target the interpreter running this script
    out = subprocess.check_output(
        ["uv", "pip", "list", "--python", sys.executable, "--format=json"]
    )

    packages = {p["name"]: p["version"] for p in json.loads(out)}

    return packages


def main() -> None:
    ioc_version = sys.argv[1] if len(sys.argv) > 1 else "unknown"

    manifest = {
        "ioc-version": ioc_version,
        "generated-at": datetime.now(timezone.utc).isoformat(),
        "epics-modules": get_epics_modules(IBEK_SUPPORT_ROOT),
        "python-packages": get_python_packages(),
    }

    OUTPUT_PATH.write_text(json.dumps(manifest, indent=2))

    print(
        f"wrote manifest with {len(manifest['epics-modules'])} EPICS modules "
        f"and {len(manifest['python-packages'])} python packages to {OUTPUT_PATH}"
    )


if __name__ == "__main__":
    main()