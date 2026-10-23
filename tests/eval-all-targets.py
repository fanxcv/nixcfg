#!/usr/bin/env python3
"""全目标 eval 门禁：17 台机器（11 standalone HM + 3 darwin + 3 nixos）必须全部可求值。

flake.nix 的 check 传入各目标 drvPath 的 JSON；求值失败则 check 实例化即失败，
本脚本复核目标数与路径非空（机器漏注册会少目标 → 失败）。

Usage: eval-all-targets.py <targetsJson>
"""

from __future__ import annotations

import json
import sys

EXPECTED_TARGETS = 17


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    targets: dict[str, str] = json.loads(sys.argv[1])
    print(f"目标数 {len(targets)}：")
    for name, drv in sorted(targets.items()):
        print(f"  {name} -> {drv}")
    empty = sorted(name for name, drv in targets.items() if not drv)
    if len(targets) != EXPECTED_TARGETS or empty:
        print(
            f"FAIL：预期 {EXPECTED_TARGETS} 个非空目标，实得 {len(targets)}，空路径 {empty}",
            file=sys.stderr,
        )
        return 1
    print(f"OK：{len(targets)} 个目标全部可求值")
    return 0


if __name__ == "__main__":
    sys.exit(main())
