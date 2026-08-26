# PVE 机器公共配置（系统层共享默认；各机器在 pve/<host>/default.nix 引用，可按需覆盖）
# 全部 PVE 宿主机统一：DNS 列表、镜像、pve-assist 源
{
  # 内网 DNS（10.21.1.1，与 razer 同网段）优先，公共 DNS 兜底；所有 PVE 机器统一
  dns = [
    "10.21.1.1"
    "119.29.29.29"
    "223.5.5.5"
  ];
  mirror = "https://mirrors.ustc.edu.cn"; # 中科大镜像
  suite = "trixie"; # PVE 9 = Debian 13
  gateway = "10.2.241.254"; # 默认网关；HP ProBook 使用其 10.2.237.254 覆盖
  pveAssistBase = "https://help.quanshan.cn/pve-assist";
  # 公共 GRUB 内核参数（所有 PVE 机器；机器专属参数在 pve/<host>/ 追加）
  # 三台实况交集：quiet + intel_iommu=on（全有）；iommu=pt 为直通性能标配（pve92 缺，补上无副作用）
  # consoleblank=60：60s 无操作控制台黑屏（笔记本屏幕省电/防烧屏，lenovo 同款）
  # 注意：AMD 平台机器需改 amd_iommu=on（当前三台均 Intel）
  grubCmdline = [
    "quiet"
    "consoleblank=60"
    "intel_iommu=on"
    "iommu=pt"
  ];
  # 公共 modprobe（四台交集：nvidiafb 黑名单；机器专属在 pve/<host>/ 的 modprobeHost 里）
  modprobePublic = ''
    # 由 nixcfg 渲染（公共，见 pve/default.nix）；旧 pve-blacklist.conf 保留兼容
    blacklist nvidiafb
  '';
  # tailscale 转发规则（仅 fan/mi 两台 tailscale 网关机开）：
  #   iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
  #   iptables -A FORWARD -o tailscale0 -j ACCEPT
  # 供外部服务器（无 tailscale）经本机转发访问 10.1.0.0/24；systemd unit 持久化（重启自动恢复）
  tailscaleForward = false;
}
