# hp（10.2.237.149，HP ProBook 450 G10 笔记本，PVE 9.2 宿主机）系统层定义
# 机器专属：盒盖不休眠（笔记本 lid ignore，logind drop-in）；tailscale 不装
{ pkgs, lib, ... }:
let
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
import ../mkHost.nix {
  inherit pkgs lib hpExtra;
  hostName = "hp";
  ip = "10.2.237.149/23";
  gateway = "10.2.237.254";
}
