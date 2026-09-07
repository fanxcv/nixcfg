# 发行版服务器 hostname 固定模块（B 路线：系统层归发行版，nix 用户态补一刀）
# HM 的 hostName 只是元数据，不设置系统 hostname；此处 activation 显式 hostnamectl。
# 启用：机器层 softwares.hostname.enable = true。

{
  config,
  lib,
  hostName,
  ...
}:
{
  options.softwares.hostname.enable = lib.mkEnableOption "hostname 固定（hostnamectl）";

  config = lib.mkIf config.softwares.hostname.enable {
    home.activation.setHostname = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      CURRENT=$(hostname)
      if [ "$CURRENT" != "${hostName}" ]; then
        hostnamectl set-hostname ${hostName}
        echo "[hostname] ${hostName}: ''${CURRENT} → ${hostName}"
      fi
    '';
  };
}
