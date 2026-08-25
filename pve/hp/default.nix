# hp（10.2.237.149，HP ProBook 450 G10 笔记本，PVE 9.0.11 宿主机，Debian 13 trixie）系统层定义
# 机器专属：盒盖不休眠（笔记本 lid ignore，logind drop-in）+ tailscaled unit（nix 二进制）
# 注意：modprobeHost 键含点必须引号
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
  # 笔记本专属 apply 段：lid ignore + tailscaled（nix 包二进制，state 全新需手动 tailscale up 认证）
  hpExtra = ''
    echo "==> [6.5/7] 笔记本专属：盒盖不休眠 + tailscaled unit"
    mkdir -p /etc/systemd/logind.conf.d
    cat > /etc/systemd/logind.conf.d/10-lid-ignore.conf <<'EOF'
    [Login]
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    HandleLidSwitchDocked=ignore
    EOF
    systemctl restart systemd-logind
    cat > /etc/systemd/system/tailscaled.service <<'EOF'
    [Unit]
    Description=Tailscale daemon (nix 管理)
    After=network-online.target
    Wants=network-online.target
    [Service]
    ExecStart=/root/.nix-profile/bin/tailscaled
    Restart=on-failure
    [Install]
    WantedBy=multi-user.target
    EOF
    systemctl daemon-reload
    systemctl enable --now tailscaled
    echo "lid ignore + tailscaled 已配置（tailscale up 认证请手动执行）"
  '';
in
{
  inherit (common) dns mirror pveAssistBase modprobePublic;
  suite = "trixie";                              # PVE 9 = Debian 13
  grubCmdline = common.grubCmdline;
  inherit hpExtra;
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline;
    modprobePublic = common.modprobePublic;
  };
}
