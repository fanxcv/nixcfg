# hp（10.2.237.149，HP ProBook 450 G10 笔记本，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：盒盖不休眠（笔记本 lid ignore，logind drop-in）
# 注意：modprobeHost 键含点必须引号
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
  ip = "10.2.237.149/23";                        # 静态 IP（apply 写 vmbr0）
  gateway = "10.2.237.254";
  # 笔记本专属 apply 段：lid ignore（tailscale 不装——仅 fan/mi 两台 PVE 有）
  hpExtra = ''
    echo "==> [6.5/7] 笔记本专属：盒盖不休眠"
    mkdir -p /etc/systemd/logind.conf.d
    cat > /etc/systemd/logind.conf.d/10-lid-ignore.conf <<'EOF'
    [Login]
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    HandleLidSwitchDocked=ignore
    EOF
    systemctl restart systemd-logind
    echo "lid ignore 已配置（合盖不休眠）"
  '';
in
{
  inherit (common) dns mirror pveAssistBase modprobePublic;
  suite = "trixie";                              # PVE 9 = Debian 13
  grubCmdline = common.grubCmdline;
  inherit hpExtra;
  inherit ip gateway;
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline;
    modprobePublic = common.modprobePublic;
    inherit ip gateway;
  };
}
