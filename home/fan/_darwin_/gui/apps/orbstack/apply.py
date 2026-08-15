#!/usr/bin/env python3
"""OrbStack 声明式配置注入（幂等，激活期执行，macOS 三台共享）

用法: apply.py <~/.orbstack目录> <内存MiB> <镜像加速URL...>（空格分隔多镜像，空=不处理 docker.json）

提取自 mba-m5 实机（orb config show 与落盘文件对照）：OrbStack 只在值≠默认时落盘
vmconfig.json（验证：set 默认值会移除 key），实机非默认配置：
  vmconfig.json          VM 资源：memory_mib（GUI/CLI 改设置会整体重写此文件，激活收敛）
  config/docker.json     Docker Engine 配置（daemon.json 风格）：registry-mirrors
其余 orb config 项（expose_ports_to_lan/start_at_login 等）均为默认，无需声明。
文件不存在时按需创建；JSON 幂等收敛，未知 key 原样保留。
"""
import json
import os
import sys

ORB_DIR = os.path.expanduser(sys.argv[1])
MEMORY_MIB = int(sys.argv[2])
MIRRORS = sys.argv[3].split()


def load_or(path, default):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return dict(default)


def save(path, data):
    # tab 缩进与 OrbStack 自身写入格式一致，diff 友好
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent="\t")
        f.write("\n")


def converge(path, default, wanted, note):
    data = load_or(path, default)
    changed = [f"{k}={v}" for k, v in wanted.items() if data.get(k) != v]
    if changed:
        for k, v in wanted.items():
            data[k] = v
        save(path, data)
        print(f"orbstack: {note} 更新 {', '.join(changed)}")
    else:
        print(f"orbstack: {note} 已符合（{', '.join(str(v) for v in wanted.values())}）")


if __name__ == "__main__":
    converge(os.path.join(ORB_DIR, "vmconfig.json"), {}, {"memory_mib": MEMORY_MIB}, "vmconfig.json")
    if MIRRORS:
        converge(os.path.join(ORB_DIR, "config", "docker.json"), {},
                 {"registry-mirrors": MIRRORS}, "docker.json")
    else:
        print("orbstack: docker.json 跳过（useChinaMirror=false，不注入镜像）")
