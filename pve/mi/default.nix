# mi（10.2.241.92，原 pve 节点改名而来，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：modprobe kvm ignore_msrs + 核显/声卡黑名单（原 pve-blacklist.conf，同名覆盖）
# tailscaleState：mi 专属——tailscale state nix 化（换机/重建恢复同 IP 10.1.0.25）
# 注意：modprobeHost 键含点必须引号
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
  ip = "10.2.241.92/24";                        # 静态 IP（apply 写 vmbr0）
  gateway = "10.2.241.254";
  modprobeHost = {
    "kvm.conf" = "options kvm ignore_msrs=1";
    "pve-blacklist.conf" = ''
      # 由 nixcfg 渲染（mi 专属，原 pve-blacklist.conf 同名覆盖）；nvidiafb 见公共 nixcfg-public.conf
      blacklist i915
      blacklist snd_hda_intel
      blacklist snd_hda_codec_hdmi
      options vfio_iommu_type1 allow_unsafe_interrupts=1
    '';
  };
  # podman nix 化：quadlet 依赖 systemd system-generator（apt 包装到 /usr/lib/systemd/），
  # nix 包 podman 自带 generator → 链接到系统目录（幂等；luckyApply 的 daemon-reload 即生效）
  miExtra = ''
    echo "==> [6.6/7] podman system-generator 链接（nix 包 podman 的 quadlet 支持）"
    mkdir -p /usr/lib/systemd/system-generators
    ln -sf ${pkgs.podman}/lib/systemd/system-generators/podman-system-generator /usr/lib/systemd/system-generators/podman-system-generator
    systemctl daemon-reload
    echo "podman quadlet generator 已链接（${pkgs.podman.name}）"
  '';
in
{
  inherit (common) dns mirror pveAssistBase modprobePublic;
  suite = "trixie";                              # 从 8.4（bookworm）升级至 9.2
  grubCmdline = common.grubCmdline;
  inherit modprobeHost;
  inherit miExtra;
  inherit ip gateway;
  tailscaleForward = true;    # tailscale 网关转发规则（外部转发经本机访问 10.1.0.0/24）
  tailscaleState = ../../secrets/hosts/mi/tailscale-mi-state.age;
  luckyData = ../../secrets/hosts/mi/lucky-data.age;    # lucky 配置归档（podman quadlet + age；web 面板改规则后重新导出）
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline;
    modprobePublic = common.modprobePublic;
    inherit modprobeHost;
    tailscaleForward = true;
    inherit ip gateway;
  };
}
