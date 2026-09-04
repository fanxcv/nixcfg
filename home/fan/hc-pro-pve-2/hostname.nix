# hc-pro-pve-2 hostname 固定（B 路线系统层归发行版，nix 用户态补一刀）
# HM 的 hostName 只是元数据，不设置系统 hostname；此处 activation 显式 hostnamectl
# hostnamectl 是系统工具（激活环境 PATH 已含系统 PATH），幂等

{
  lib,
  ...
}:
{
  home.activation.setHostname = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CURRENT=$(hostname)
    if [ "$CURRENT" != "hc-pro-pve-2" ]; then
      hostnamectl set-hostname hc-pro-pve-2
      echo "[hostname] hc-pro-pve-2: ''${CURRENT} → hc-pro-pve-2"
    fi
  '';
}
