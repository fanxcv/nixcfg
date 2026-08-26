# ClashX Meta（代理客户端）声明式安装 + 配置注入（macOS 三台共享）
# 安装：GitHub release zip 下载（githubProxy 门控：useChinaMirror=true 走 ghfast 前缀，false 直连）
#       → ditto 解压 /Applications → 去 quarantine；版本不符才下载，升级改 version 重部署即可
# 配置：defaults write com.metacubex.ClashX.meta（订阅列表 kRemoteConfigs / 当前配置 selectConfigName
#       / 允许局域网 allowConnectFromLan / 实时网速 showNetSpeedIndicator / 订阅自动更新 kAutoUpdateEnable）
# 订阅：下载订阅内容 → ~/.config/clash/fan-x.yaml，注入 mixed-port（ClashX 读 config 的 mixed-port 作混合端口）
# 注意：App 运行中不热重载——部署后重启 App 生效（脚本只提示，不 killall）；
#       自动升级核心为 ClashX Meta 默认行为，无需注入；开机自启走登录项（非 defaults），App 内勾选一次
{ pkgs, lib, tools, ... }:
let
  cfg = tools.config;
  # 升级：改 version（GitHub release 版本号），重新部署自动下载替换
  version = "1.4.43";
  baseUrl = "https://github.com/MetaCubeX/ClashX.Meta/releases/download/v${version}/ClashX.Meta.zip";
  # useChinaMirror 门控：走国内镜像时套 githubProxy 前缀，否则直连 GitHub
  downloadUrl = if cfg.useChinaMirror && cfg.githubProxy != "" then cfg.githubProxy + baseUrl else baseUrl;
in
{
  home.activation.setupClashXMeta = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 ${./clashx-meta/apply.py} \
      "${version}" "${downloadUrl}" \
      "https://xx.fan-x.eu.org/api/v1/client/subscribe?token=eaa63ab248c016278df7f8f6d2847757" \
      "7890" "true" "true" "true"
  '';
}
