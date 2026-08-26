#!/usr/bin/env python3
"""ClashX Meta 声明式安装 + 配置注入（幂等，激活期执行，macOS 三台共享）

用法: apply.py <版本> <下载URL> <订阅URL> <混合端口> <允许局域网> <显示网速> <自动更新订阅>

安装（版本不符才下载）：
  curl 下载 GitHub release zip（URL 已含 githubProxy 前缀，useChinaMirror 门控）→ ditto 解压 /Applications → 去 quarantine
配置（defaults write com.metacubex.ClashX.meta，key 均源码实证）：
  kRemoteConfigs        订阅列表（JSON 数组，url/name）——App 内「配置→托管配置」可见
  selectConfigName      当前生效配置名 → 读 ~/.config/clash/<name>.yaml
  allowConnectFromLan   允许局域网连接（启动时经 Clash API 应用）
  showNetSpeedIndicator 菜单栏实时网速
  kAutoUpdateEnable     订阅自动更新（默认 2h 一次）
订阅：下载订阅内容 → ~/.config/clash/<name>.yaml，注入 mixed-port（ClashX 读 config 的 mixed-port 作混合端口）
逐项检查，已符合则跳过；可重复执行。App 运行中不热重载——部署后重启 App 生效（脚本只提示，不 killall）。
注：自动升级核心为 ClashX Meta 默认行为（App 启动自动检查），无需注入。
"""
import json
import os
import re
import subprocess
import sys
import urllib.request

VERSION = sys.argv[1]
DOWNLOAD_URL = sys.argv[2]
SUB_URL = sys.argv[3]
MIXED_PORT = sys.argv[4]
ALLOW_LAN = sys.argv[5] == "true"
SHOW_NET_SPEED = sys.argv[6] == "true"
AUTO_UPDATE_SUB = sys.argv[7] == "true"
SUB_NAME = "fan-x"

BUNDLE_ID = "com.metacubex.ClashX.meta"
APP_PATH = "/Applications/ClashX Meta.app"
CONFIG_DIR = os.path.expanduser("~/.config/clash")
SUB_FILE = os.path.join(CONFIG_DIR, SUB_NAME + ".yaml")
ZIP_PATH = f"/tmp/ClashX.Meta-{VERSION}.zip"


def installed_version():
    """已装 App 版本（Info.plist CFBundleShortVersionString）；未装返回 None"""
    plist = os.path.join(APP_PATH, "Contents", "Info.plist")
    if not os.path.exists(plist):
        return None
    try:
        out = subprocess.run(
            ["plutil", "-extract", "CFBundleShortVersionString", "raw", plist],
            capture_output=True, text=True, check=True)
        return out.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def app_running():
    return subprocess.run(["pgrep", "-f", "ClashX Meta"],
                          capture_output=True).returncode == 0


def ensure_installed():
    cur = installed_version()
    if cur == VERSION:
        print(f"clashx-meta: 已装 {VERSION}，跳过下载")
        return
    if app_running():
        # App 运行中替换会因文件占用失败——不 killall，提示退出后重跑部署完成升级
        print(f"警告: ClashX Meta 运行中（当前 {cur or '未装'}），跳过安装——退出 App 后重跑部署完成升级到 {VERSION}")
        return
    print(f"clashx-meta: 安装 {VERSION}（当前 {cur or '未装'}）")
    # 下载失败即部署失败（安装前置步骤，不吞错）
    subprocess.run(["curl", "-L", "--fail", "--max-time", "600",
                    "-o", ZIP_PATH, DOWNLOAD_URL], check=True)
    # 解压到 /Applications（ditto 保留权限/符号链接；zip 内为 ClashX Meta.app）
    subprocess.run(["ditto", "-x", "-k", ZIP_PATH, "/Applications"], check=True)
    # 去 quarantine（GitHub 直装 app 未公证，Gatekeeper 拦截；文件无此属性时忽略）
    subprocess.run(["xattr", "-d", "com.apple.quarantine", APP_PATH],
                   capture_output=True)  # 幂等：属性不存在报错可忽略
    print(f"clashx-meta: 安装完成 {VERSION}")


def defaults_write(key, *args):
    subprocess.run(["defaults", "write", BUNDLE_ID, key, *args], check=True)


def ensure_defaults():
    changed = []
    # 订阅列表：JSON 数组（RemoteConfigModel Codable，url/name；updateTime nil 省略）
    data = json.dumps([{"url": SUB_URL, "name": SUB_NAME}]).encode()
    out = subprocess.run(["defaults", "read", BUNDLE_ID, "kRemoteConfigs"],
                         capture_output=True, text=True)
    if out.returncode != 0 or SUB_URL not in out.stdout:
        defaults_write("kRemoteConfigs", "-data", data.hex())
        changed.append("kRemoteConfigs")
    # 当前生效配置 = 订阅名（App 读 ~/.config/clash/fan-x.yaml）
    out = subprocess.run(["defaults", "read", BUNDLE_ID, "selectConfigName"],
                         capture_output=True, text=True)
    if out.returncode != 0 or out.stdout.strip() != SUB_NAME:
        defaults_write("selectConfigName", "-string", SUB_NAME)
        changed.append("selectConfigName")
    # 允许局域网连接
    out = subprocess.run(["defaults", "read", BUNDLE_ID, "allowConnectFromLan"],
                         capture_output=True, text=True)
    if out.returncode != 0 or out.stdout.strip() != "1":
        defaults_write("allowConnectFromLan", "-bool", "true")
        changed.append("allowConnectFromLan")
    # 菜单栏实时网速
    out = subprocess.run(["defaults", "read", BUNDLE_ID, "showNetSpeedIndicator"],
                         capture_output=True, text=True)
    if out.returncode != 0 or out.stdout.strip() != "1":
        defaults_write("showNetSpeedIndicator", "-bool", "true")
        changed.append("showNetSpeedIndicator")
    # 订阅自动更新（默认 true，显式收敛）
    out = subprocess.run(["defaults", "read", BUNDLE_ID, "kAutoUpdateEnable"],
                         capture_output=True, text=True)
    if out.returncode != 0 or out.stdout.strip() != "1":
        defaults_write("kAutoUpdateEnable", "-bool", "true")
        changed.append("kAutoUpdateEnable")
    if changed:
        print("clashx-meta: defaults 更新 " + ", ".join(changed))
    else:
        print("clashx-meta: defaults 已符合（订阅/当前配置/局域网/网速/自动更新）")


def ensure_subscription():
    os.makedirs(CONFIG_DIR, exist_ok=True)
    msgs = []
    if not os.path.exists(SUB_FILE):
        try:
            req = urllib.request.Request(SUB_URL, headers={"User-Agent": "ClashX/1.4.43"})
            with urllib.request.urlopen(req, timeout=20) as r:
                data = r.read()
            with open(SUB_FILE, "wb") as f:
                f.write(data)
            msgs.append(f"订阅内容已下载（{len(data)}B）")
        except Exception as e:  # noqa: BLE001 —— 网络失败不阻断部署（App 内可手动更新）
            print(f"警告: 订阅内容下载失败（App 内手动更新即可）：{e}")
            return
    # 注入 mixed-port（ClashX 读 config 的 mixed-port 作混合端口；存在替换/缺失追加）
    with open(SUB_FILE, encoding="utf-8") as f:
        text = f.read()
    pat = re.compile(r"^mixed-port:\s*\S.*$", re.M)
    line = f"mixed-port: {MIXED_PORT}"
    if pat.search(text):
        if pat.sub(line, text, count=1) != text:
            with open(SUB_FILE, "w", encoding="utf-8") as f:
                f.write(pat.sub(line, text, count=1))
            msgs.append(f"mixed-port 已更新为 {MIXED_PORT}")
        else:
            msgs.append(f"mixed-port 已符合 {MIXED_PORT}")
    else:
        with open(SUB_FILE, "w", encoding="utf-8") as f:
            f.write(line + "\n" + text)
        msgs.append(f"mixed-port {MIXED_PORT} 已注入")
    print("clashx-meta: " + "；".join(msgs))


if __name__ == "__main__":
    ensure_installed()
    ensure_defaults()
    ensure_subscription()
    if app_running():
        print("clashx-meta: App 运行中——配置已写入，重启 App 后完整生效")
