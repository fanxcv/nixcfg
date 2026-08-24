# ds2 系统层配置渲染（PVE 9.2 宿主机，Debian 13 trixie）
# 非 NixOS：本文件只渲染配置文件文本（apt 源 / DNS），部署编排见 ../deploy.nix（flake packages.ds2）
# 去订阅 nag 走 pve-assist 的 --repair-subscription-if-stale（自带 marker 补丁，见 apply.sh）
{ pkgs, lib, ... }:
let
  common = import ../default.nix;             # PVE 公共层（DNS/mirror/pveAssistBase/grubCmdline）
  dns = common.dns;                          # 内网 10.21.1.1 优先 + 公共 DNS 兜底
  mirror = common.mirror;
  suite = "trixie";                              # PVE 9 = Debian 13
  pveAssistBase = common.pveAssistBase;
  grubCmdline = common.grubCmdline;         # 公共：quiet + consoleblank=60（机器专属参数在此追加）
in
{
  inherit dns mirror suite pveAssistBase grubCmdline;

  # 渲染 /tmp/ds2-deploy/ 下的系统配置文件（scp 推送后 apply.sh 引用）
  files = pkgs.runCommand "ds2-sysfiles" { } ''
    mkdir -p $out

    # Debian 主源（deb822，中科大）
    cat > $out/debian.sources <<EOF
    Types: deb
    URIs: ${mirror}/debian/
    Suites: ${suite} ${suite}-updates ${suite}-backports
    Components: main contrib non-free non-free-firmware
    Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
    EOF

    # Debian security 源（deb822，中科大）
    cat > $out/debian-security.sources <<EOF
    Types: deb
    URIs: ${mirror}/debian-security/
    Suites: ${suite}-security
    Components: main contrib non-free non-free-firmware
    Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
    EOF

    # PVE no-subscription 源（中科大；替换 enterprise 源，黄色提示根源）
    cat > $out/pve-no-subscription.list <<EOF
    deb ${mirror}/proxmox/debian/pve ${suite} pve-no-subscription
    EOF

    # DNS（systemd-resolved；PVE 9 默认启用）
    cat > $out/resolved.conf <<EOF
    [Resolve]
    DNS=${builtins.concatStringsSep " " dns}
    FallbackDNS=${builtins.concatStringsSep " " (lib.lists.reverseList dns)}
    EOF

    # GRUB（/etc/default/grub；GRUB_CMDLINE_LINUX_DEFAULT 含公共参数）
    cat > $out/grub <<EOF
    GRUB_DEFAULT=0
    GRUB_TIMEOUT=5
    GRUB_DISTRIBUTOR=\`lsb_release -i -s 2> /dev/null || echo Debian\`
    GRUB_CMDLINE_LINUX_DEFAULT="${builtins.concatStringsSep " " grubCmdline}"
    GRUB_CMDLINE_LINUX=""
    EOF
  '';
}
