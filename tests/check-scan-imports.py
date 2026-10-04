#!/usr/bin/env python3
"""tools.scan 未导入检查：扫描目录内不存在被静默跳过的 .nix。

tools/scan.nix 只导入「直接子 .nix 文件（除 default.nix）」与「含 default.nix 的子目录」；
无 default.nix 的子目录里埋的 .nix 不会被 scan 导入（AGENTS.md 已记）。本脚本 grep 全仓
tools.scan 使用点，对每个被扫描目录断言：其中的 .nix 都被导入——直接子文件由 scan 导入，
无 default.nix 子目录内的文件必须在别处被显式 import（如数据文件），否则即静默跳过 → 失败。

Usage: check-scan-imports.py <repoRoot>
"""

from __future__ import annotations

import os
import re
import sys

SCAN_USE = re.compile(r"tools\.scan\s+([^\s;)]+)")


def read_text(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def walk_nix(root: str):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for name in filenames:
            if name.endswith(".nix"):
                yield os.path.join(dirpath, name)


def find_scan_dirs(root: str) -> list[str]:
    dirs: set[str] = set()
    for path in walk_nix(root):
        for line in read_text(path).splitlines():
            match = SCAN_USE.search(line.split("#", 1)[0])
            if match:
                arg = match.group(1).strip('"')
                dirs.add(os.path.normpath(os.path.join(os.path.dirname(path), arg)))
    return sorted(dirs)


def is_imported(root: str, path: str, texts: dict[str, str]) -> bool:
    # 末两段路径（如 edge-ext/data.nix）出现在其他 .nix 中即视为已显式 import
    tail = "/".join(os.path.relpath(path, root).split(os.sep)[-2:])
    return any(tail in text for other, text in texts.items() if other != path)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    root = sys.argv[1]
    scan_dirs = find_scan_dirs(root)
    if not scan_dirs:
        print("FAIL：未找到任何 tools.scan 使用点（grep 失效？）", file=sys.stderr)
        return 1
    texts = {path: read_text(path) for path in walk_nix(root)}
    skipped: list[tuple[str, str]] = []
    for scan_dir in scan_dirs:
        if not os.path.isdir(scan_dir):
            print(f"FAIL：scan 目录不存在 {scan_dir}", file=sys.stderr)
            return 1
        for name in sorted(os.listdir(scan_dir)):
            sub = os.path.join(scan_dir, name)
            if not os.path.isdir(sub) or os.path.exists(os.path.join(sub, "default.nix")):
                continue
            for dirpath, _dirnames, filenames in os.walk(sub):
                for fname in filenames:
                    if fname.endswith(".nix"):
                        path = os.path.join(dirpath, fname)
                        if not is_imported(root, path, texts):
                            skipped.append((scan_dir, path))
    print(f"扫描目录 {len(scan_dirs)} 个，.nix 文件 {len(texts)} 个")
    if skipped:
        print("FAIL：以下 .nix 位于无 default.nix 的子目录且未被 import（静默跳过）：", file=sys.stderr)
        for scan_dir, path in skipped:
            print(
                f"  {os.path.relpath(path, root)}（扫描目录 {os.path.relpath(scan_dir, root)}）",
                file=sys.stderr,
            )
        return 1
    print("OK：无被静默跳过的 .nix")
    return 0


if __name__ == "__main__":
    sys.exit(main())
