#!/usr/bin/env python3
"""输出集合断言：flake.nix 三大配置族键集与机器别名集合必须等于迁移前基线。

flake.nix 的 homeConfigurations / darwinConfigurations / nixosConfigurations 与
packages 机器别名全部由 tools/machines.nix 派生（见 flake.nix）。本检查接收 flake
实际输出集合（JSON），与固定基线比对：机器漏注册/多注册即失败。

Usage: machine-sets.py <homeKeysJson> <darwinKeysJson> <nixosKeysJson> <aliasKeysJson>
"""

from __future__ import annotations

import json
import sys

# 迁移前基线（输出名与别名集合必须完全不变）
EXPECTED_HOME = [
    "fan@desktop",
    "fan@ds2",
    "fan@fan",
    "fan@hp",
    "fan@mi",
    "fan@razer",
    "fan@ide-si",
    "fan@ide-lenovo",
    "fan@ide-mac",
    "root@ali-ai",
    "root@hc-pro-pve-2",
]
EXPECTED_DARWIN = ["mba-m5", "mbp-m1", "mini-m4"]
EXPECTED_NIXOS = ["nix-lenovo", "nix-book", "nix-asus"]
EXPECTED_ALIAS = [
    "ide-si",
    "ide-lenovo",
    "ide-mac",
    "ali-ai",
    "hc-pro-pve-2",
    "ds2",
    "desktop",
    "fan",
    "hp",
    "mi",
    "razer",
    "mba-m5",
    "mbp-m1",
    "mini-m4",
]


def check(label: str, actual: list[str], expected: list[str]) -> bool:
    """比对集合，缺/多均打印并返回失败。"""
    if sorted(actual) == sorted(expected):
        print(f"OK  {label}: {len(actual)} 项")
        return True
    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    print(f"FAIL {label}: 缺 {missing} / 多 {extra}", file=sys.stderr)
    return False


def main() -> int:
    if len(sys.argv) != 5:
        print(__doc__, file=sys.stderr)
        return 2
    home, darwin, nixos, alias = (json.loads(arg) for arg in sys.argv[1:5])
    ok = all(
        [
            check("homeConfigurations", home, EXPECTED_HOME),
            check("darwinConfigurations", darwin, EXPECTED_DARWIN),
            check("nixosConfigurations", nixos, EXPECTED_NIXOS),
            check("机器别名", alias, EXPECTED_ALIAS),
        ]
    )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
