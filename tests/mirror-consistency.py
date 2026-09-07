#!/usr/bin/env python3
"""Regression test: the hand-maintained binary-cache mirror locations stay in sync.

Three places must match, all mirroring the single source of truth tools/config.nix:
  1. tools/config.nix            — nixSubstituters / nixCachixSubstituters / nixCachixTrustedPublicKeys (runtime source)
  2. flake.nix nixConfig         — static literal (flake resolver can't read tools/ during parse)
  3. docker/ide/ubuntu/Dockerfile— /etc/nix/nix.conf printf string (build-time, can't import Nix attrsets)

modules/darwin/nix.nix and hosts/nix-pve read tools.config.nix directly and therefore
follow the source automatically; they need no assertion here.

Any drift fails the check and prints the differing values.
Usage: mirror-consistency.py <config.nix> <flake.nix> <Dockerfile>
"""

import re
import sys
from pathlib import Path

# Canonical mirror groups, keyed by the flake.nix / Dockerfile spelling.
CANONICAL = ["substituters", "extra-substituters", "extra-trusted-public-keys"]
# tools/config.nix variable name for each canonical key.
SOURCE_VAR = {
    "substituters": "nixSubstituters",
    "extra-substituters": "nixCachixSubstituters",
    "extra-trusted-public-keys": "nixCachixTrustedPublicKeys",
}


def nix_list_values(text: str, var: str) -> list[str]:
    """Extract the string list assigned to `var` in Nix source (up to matching ']')."""
    match = re.search(rf"{re.escape(var)}\s*=\s*\[(.*?)\]", text, re.S)
    if not match:
        return []
    return re.findall(r'"([^"]*)"', match.group(1))


def flake_nix_values(text: str) -> dict[str, list[str]]:
    """Parse the nixConfig block of flake.nix into canonical key -> values."""
    match = re.search(r"nixConfig\s*=\s*\{(.*?)\};", text, re.S)
    block = match.group(1) if match else ""

    def values(key: str) -> list[str]:
        return re.findall(rf"{re.escape(key)}\s*=\s*\[(.*?)\]", block, re.S)\
            and re.findall(r'"([^"]*)"', re.search(
                rf"{re.escape(key)}\s*=\s*\[(.*?)\]", block, re.S).group(1))

    return {key: values(key) for key in CANONICAL}


def dockerfile_values(text: str) -> dict[str, list[str]]:
    """Parse the /etc/nix/nix.conf printf block of the Dockerfile."""
    match = re.search(r"printf\s+'(.*?)'\s*>\s*/etc/nix/nix.conf", text, re.S)
    if not match:
        return {key: [] for key in CANONICAL}
    conf = match.group(1).replace("\\n", "\n")
    out: dict[str, list[str]] = {key: [] for key in CANONICAL}
    for line in conf.splitlines():
        if "=" not in line or line.lstrip().startswith("#"):
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        if key in out:
            out[key] = value.strip().split()
    return out


def main() -> None:
    config_nix, flake_nix, dockerfile = (Path(p) for p in sys.argv[1:4])
    source = config_nix.read_text()
    flake = flake_nix.read_text()
    docker = dockerfile.read_text()

    source_values = {
        key: nix_list_values(source, SOURCE_VAR[key]) for key in CANONICAL
    }
    flake_values = flake_nix_values(flake)
    docker_values = dockerfile_values(docker)

    failures = []
    for key in CANONICAL:
        expected = source_values[key]
        for name, actual in (
            ("flake.nix nixConfig", flake_values[key]),
            ("Dockerfile nix.conf", docker_values[key]),
        ):
            if actual != expected:
                failures.append(
                    f"[{key}] {name} 不一致:\n"
                    f"    tools/config.nix: {expected}\n"
                    f"    {name}:            {actual}"
                )

    if failures:
        print("镜像配置一致性检查失败：")
        print("\n".join(failures))
        sys.exit(1)

    print(
        f"OK: 镜像配置一致 "
        f"(主源 {len(source_values['substituters'])}、"
        f"cachix 补充 {len(source_values['extra-substituters'])}、"
        f"公钥 {len(source_values['extra-trusted-public-keys'])})"
    )


if __name__ == "__main__":
    main()
