# mi（10.2.241.92，原 pve 节点改名而来，PVE 9.2 宿主机）系统层定义
# 机器专属：vfio 直通、tailscale 网关、podman quadlet 与 lucky 配置归档
# 注意：modprobeHost 键含点必须引号
{ pkgs, lib, ... }:
let
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
  # podman nix 化：目标机从 /root/.nix-profile 解析实际 generator，避免部署机架构路径泄漏
  miExtra = ''
    echo "==> [6.6/7] podman system-generator 链接（nix 包 podman 的 quadlet 支持）"
    mkdir -p /usr/lib/systemd/system-generators
    rm -f /usr/lib/systemd/system-generators/podman-system-generator
    cat > /usr/lib/systemd/system-generators/podman-system-generator <<'WRAPPER'
    #!/bin/sh
    GEN=$(readlink -f /root/.nix-profile/lib/systemd/system-generators/podman-system-generator 2>/dev/null)
    if [ -n "$GEN" ] && [ -x "$GEN" ]; then
      exec "$GEN" "$@"
    fi
    echo "podman-system-generator: 未找到 nix podman generator（/root/.nix-profile）" >&2
    exit 1
    WRAPPER
    chmod +x /usr/lib/systemd/system-generators/podman-system-generator
    systemctl daemon-reload
    echo "podman quadlet generator 已链接（wrapper → nix profile）"
  '';
in
import ../mkHost.nix {
  inherit
    pkgs
    lib
    modprobeHost
    miExtra
    ;
  hostName = "mi";
  ip = "10.2.241.92/24";
  tailscaleForward = true;
  tailscaleState = ../../secrets/hosts/mi/tailscale-mi-state.age;
  luckyData = ../../secrets/hosts/mi/lucky-data.age;
}
