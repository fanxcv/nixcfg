#!/usr/bin/env python3
"""Regression test: the hand-maintained binary-cache mirror locations stay in sync.

Four places must match exactly, all mirroring the single source of truth tools/config.nix:
  1. tools/config.nix            — nixSubstituters / nixCachixSubstituters / nixCachixTrustedPublicKeys (runtime source)
  2. flake.nix nixConfig         — static literal (flake resolver can't read tools/ during parse)
  3. docker/ide/ubuntu/Dockerfile— /etc/nix/nix.conf printf string (build-time, can't import Nix attrsets)
  4. docker/ide/ubuntu/entrypoint.sh — /etc/nix/nix.conf heredoc fallback (runtime, same reason)
A fifth place is checked as a subset (it only declares the keys it needs):
  5. pve/deploy.sh               — /etc/nix/nix.conf heredoc for PVE hosts (plain shell, no cachix keys)

modules/darwin/nix.nix and hosts/<机>/default.nix read tools.config.nix directly and therefore
follow the source automatically; they need no assertion here.
Additionally checked: tools/config.nix dockerRegistryMirrors vs the hand-written
registries.conf.d drop-in in pve/apply.sh (6th argument, or sibling of the
pve/deploy.sh argument when omitted; podman tries mirrors in order, so exact match).

Any drift fails the check and prints the differing values.
Usage: mirror-consistency.py <config.nix> <flake.nix> <Dockerfile> <entrypoint.sh> <pve-deploy.sh> [pve-apply.sh]
"""

from __future__ import annotations

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


def nix_conf_values(text: str) -> dict[str, list[str]]:
    """Parse a nix.conf body (key = space-separated values) into canonical key -> values."""
    out: dict[str, list[str]] = {key: [] for key in CANONICAL}
    for line in text.splitlines():
        if "=" not in line or line.lstrip().startswith("#"):
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        if key in out:
            out[key] = value.strip().split()
    return out


def dockerfile_values(text: str) -> dict[str, list[str]]:
    """Parse the /etc/nix/nix.conf printf block of the Dockerfile."""
    match = re.search(r"printf\s+'(.*?)'\s*>\s*/etc/nix/nix.conf", text, re.S)
    if not match:
        return {key: [] for key in CANONICAL}
    return nix_conf_values(match.group(1).replace("\\n", "\n"))


def entrypoint_values(text: str) -> dict[str, list[str]]:
    """Parse the /etc/nix/nix.conf heredoc fallback block of the container entrypoint."""
    match = re.search(
        r"cat\s+>>\s+\"\$NIXCONF\"\s+<<'EOF'\n(.*?)\nEOF", text, re.S
    )
    if not match:
        return {key: [] for key in CANONICAL}
    return nix_conf_values(match.group(1))


def pve_values(text: str) -> dict[str, list[str]] | None:
    """Parse the /etc/nix/nix.conf heredoc of the PVE deploy script (None = block missing)."""
    match = re.search(
        r"cat > /etc/nix/nix.conf <<'NIXCONF'\n(.*?)\nNIXCONF", text, re.S
    )
    if not match:
        return None
    return nix_conf_values(match.group(1))


def pve_mirror_values(text: str) -> list[str] | None:
    """Parse the registries.conf.d mirror drop-in heredoc of pve/apply.sh (None = block missing)."""
    match = re.search(
        r"cat > /etc/containers/registries.conf.d/mirror\.conf <<'MIRROR'\n(.*?)\nMIRROR",
        text,
        re.S,
    )
    if not match:
        return None
    return re.findall(r'\[\[registry\.mirror\]\]\s*\n\s*location = "([^"]*)"', match.group(1))


def is_subsequence(actual: list[str], expected: list[str]) -> bool:
    """True when `actual` appears in `expected` in order (a layer may declare fewer keys/values)."""
    pool = iter(expected)
    return all(value in pool for value in actual)


def main() -> None:
    config_nix, flake_nix, dockerfile, entrypoint, pve_deploy = (
        Path(p) for p in sys.argv[1:6]
    )
    source = config_nix.read_text()
    flake = flake_nix.read_text()
    docker = dockerfile.read_text()
    entry = entrypoint.read_text()
    pve = pve_deploy.read_text()
    # pve/apply.sh：第六参显式给出（flake check 传的是单文件 store 路径，其 parent
    # 不含目录结构，无法从 deploy.sh 的 sibling 推导）；缺省时按同目录推导
    pve_apply_path = Path(sys.argv[6]) if len(sys.argv) > 6 else pve_deploy.with_name("apply.sh")
    pve_apply = pve_apply_path.read_text() if pve_apply_path.exists() else ""

    source_values = {
        key: nix_list_values(source, SOURCE_VAR[key]) for key in CANONICAL
    }
    flake_values = flake_nix_values(flake)
    docker_values = dockerfile_values(docker)
    entrypoint_conf_values = entrypoint_values(entry)
    pve_conf_values = pve_values(pve)
    pve_mirrors = pve_mirror_values(pve_apply)
    # 源头带 https:// 前缀，podman location 仅域名：按域名比较；podman 按声明顺序回退镜像，故顺序敏感，取全等（非子集）。
    source_mirrors = [
        re.sub(r"^https?://", "", mirror)
        for mirror in nix_list_values(source, "dockerRegistryMirrors")
    ]

    failures = []
    if pve_conf_values is None:
        failures.append(
            "pve/deploy.sh: 未找到 /etc/nix/nix.conf 的 NIXCONF heredoc 块（块被改名/删除？）"
        )
    if pve_mirrors is None:
        failures.append(
            "pve/apply.sh: 未找到 registries.conf.d/mirror.conf 的 MIRROR heredoc 块（块被改名/删除？）"
        )
    elif pve_mirrors != source_mirrors:
        failures.append(
            f"[dockerRegistryMirrors] pve/apply.sh mirror.conf 不一致:\n"
            f"    tools/config.nix: {source_mirrors}\n"
            f"    pve/apply.sh:      {pve_mirrors}"
        )

    for key in CANONICAL:
        expected = source_values[key]
        layers = [
            ("flake.nix nixConfig", flake_values[key], False),
            ("Dockerfile nix.conf", docker_values[key], False),
            ("entrypoint.sh nix.conf", entrypoint_conf_values[key], False),
            ("pve/deploy.sh nix.conf", (pve_conf_values or {}).get(key, []), True),
        ]
        for name, actual, subset in layers:
            if not actual and subset:
                continue  # PVE 层只声明所需键，未声明即跳过
            mismatch = (
                not is_subsequence(actual, expected) if subset else actual != expected
            )
            if mismatch:
                kind = "（子集不一致）" if subset else ""
                failures.append(
                    f"[{key}] {name} 不一致{kind}:\n"
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
