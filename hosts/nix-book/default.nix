# nix-book（MECHREVO 无界14S 笔记本：476.9G NVMe + AMD Ryzen 7 7840HS/780M 核显 + Intel AX200 无线 + KDE Plasma 桌面）
# 由 nix-lenovo 的机器层复制而来（同为用户的主力笔记本形态），硬件项按本机实测器件改写
# 公共配置在 hosts/_common_/ + hosts/_nixos_/，本目录只放本机特有项
# 部署：手动 nixos-rebuild switch --flake .#nix-book（笔记本移动设备）
{ pkgs, tools, ... }:
{
  imports =
    map tools.relative [
      "hosts/_common_/base"
      "hosts/_common_/i18n"
      "hosts/_nixos_/base"
      "hosts/_nixos_/i18n"
      "hosts/_nixos_/gui/desktop"
      "hosts/_nixos_/themes"
      "hosts/_nixos_/kernel"
      "hosts/_nixos_/services/openssh.nix"
      "hosts/_nixos_/services/podman.nix"
      "hosts/_nixos_/services/tailscale.nix"

      "users/fan"
    ]
    ++ (tools.scan ./.);

  networking.hostName = "nix-book";

  # Wayland 默认会话（无 RustDesk 被控需求，无需 X11 妥协；RustDesk 仅作 client 远程其他机器）
  services.xserver.enable = false;

  # nix 下载走国内镜像（手动 rebuild 用；root 的 nix.conf 由 NixOS 生成，天然 trusted）
  nix.settings.substituters = tools.config.nixSubstituters;
  nix.settings.extra-substituters = tools.config.nixCachixSubstituters;
  nix.settings.extra-trusted-public-keys = tools.config.nixCachixTrustedPublicKeys;

  # 本地构建：sandbox=true 时部分包构建受限，关沙箱换构建可行
  nix.settings.sandbox = false;

  # store 自动 GC（476.9G 盘，30 天保留）+ 定期硬链接优化
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 30d";
  nix.optimise.automatic = true;

  # NVMe 定期 trim（SSD 寿命/性能）
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # fan sudo 免密（日常维护/手动 rebuild 用）
  security.sudo.wheelNeedsPassword = false;

  # 蓝牙（NixOS 默认不开；AX200 的蓝牙硬件在，KDE 界面已就位，蓝牙耳机/键鼠刚需）
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # 无 WWAN 模块，ModemManager 纯耗资源，禁用（26.05 起选项为 networking.modemmanager）
  networking.modemmanager.enable = false;

  # 固件更新（BIOS/EC，Linux Vendor Firmware Service）
  services.fwupd.enable = true;

  # 不装 syncthing（用户明确不需要本机参与文件同步；共享层 home 的 ~/sync、~/share 空目录保留）
  # 不装 eden（Switch 模拟器及相应 udev 手柄规则/Nintendo 内核模块处理均不需要）

  programs.git = {
    enable = true;
    config.credential.helper = "store";
  };

  # fcitx5 中文输入法：系统层 i18n.inputMethod（NixOS 模块）自动设 IM 环境变量
  # （SDDM 图形会话 source /etc/profile 生效，home-manager sessionVariables 只进 ~/.zshenv 不覆盖图形会话）
  # + 生成 /etc/gtk-3.0/immodules.cache（GTK 默认查找路径；fcitx5-with-addons 含 fcitx5-gtk immodule）
  # 用户层 fcitx5 配置（双拼/皮肤）由 home/fan/_nixos_/i18n/zh-CN/fcitx.nix 管理
  # addons 与 home 层同 list → 系统/用户 profile 的 fcitx5-with-addons 为同一 drv，只存一份
  # waylandFrontend：本机 Wayland 会话 → 走 Wayland 前端；系统层不同步开的话
  #   environment.variables 仍会导 GTK_IM_MODULE/QT_IM_MODULE，Wayland text-input 不生效
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = [ pkgs.kdePackages.fcitx5-chinese-addons ];
    fcitx5.waylandFrontend = true;
  };
}
