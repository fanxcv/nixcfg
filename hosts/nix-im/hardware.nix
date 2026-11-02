# 硬件配置：Lenovo ThinkBook 14 G6+ IMH（Intel Core Ultra 5 125H + Arc 核显 + Intel CNVi 无线 + Intel I219-LM 有线）
# 真机（非 VM）：无 qemu-guest profile；Arc 走内核 xe/i915 + mesa（linux-firmware 默认带）
{ pkgs, ... }:
{
  # GRUB 引导（efiInstallAsRemovable：真机 UEFI 兼容性最好，无需额外配置）
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    configurationLimit = 15;
    efiInstallAsRemovable = true;
  };
  # Intel 微码：Meteor Lake 的 downcore/安全修复靠它（nix-lenovo 是 AMD，无此项）
  hardware.cpu.intel.updateMicrocode = true;

  # Arc 的硬件解码走 iHD 驱动（home 层 mpv.conf hwdec=vaapi 依赖它）；graphics.enable 在公共层
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # 笔记本电源：系统层无 TLP（tsln 同款，电源计划全在 plasma.powerdevil，见 home/fan/nix-im/）
  # 休眠恢复：swap 分区的 resumeDevice 由 disko 从 disks.nix 生成，无需手写
}
