# nix-asus（ASUS Zenbook UM5302TA，512G NVMe + AMD Ryzen 7 6800U/680M 核显 + KDE Plasma）—— 机器组装清单
# 与 Windows 双系统：原盘前 220G 归 Windows（含 260M ESP / MSR / C: 219G / RECOVERY / MYASUS），
#   NixOS 用 p3 之后的 256G 空闲区（分区布局见 disks.nix，首次安装为手工建区）
# 公共配置在 hosts/_common_/ + hosts/_nixos_/，本目录只放本机特有项
# 部署：手动 nixos-rebuild switch --flake .#nix-asus（笔记本移动设备，不用 comin 自动部署）
#   首次安装：nixos-install --flake /persist/etc/nixos#nix-asus（仓库放 /persist/etc/nixos）
{ tools, ... }:
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
      "hosts/_nixos_/services/syncthing.nix"

      "users/fan"
    ]
    ++ (tools.scan ./.);

  networking.hostName = "nix-asus";

  # Wayland 默认会话（无 RustDesk 被控需求，无需 X11 妥协）
  services.xserver.enable = false;

  # nix 下载走国内镜像（手动 rebuild 用；root 的 nix.conf 由 NixOS 生成，天然 trusted）
  nix.settings.substituters = tools.config.nixSubstituters;
  nix.settings.extra-substituters = tools.config.nixCachixSubstituters;
  nix.settings.extra-trusted-public-keys = tools.config.nixCachixTrustedPublicKeys;

  # 本地构建：sandbox=true 时部分包构建受限，关沙箱换构建可行
  nix.settings.sandbox = false;

  # store 自动 GC（512G 盘，NixOS 侧约 118G，30 天保留）+ 定期硬链接优化
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

  # 蓝牙（MT7922 自带蓝牙，KDE 界面已就位）
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # 无 WWAN 模块，ModemManager 纯耗资源，禁用（26.05 起选项为 networking.modemmanager）
  networking.modemmanager.enable = false;

  # 固件更新（BIOS/EC，Linux Vendor Firmware Service；ASUS 部分机型走 LVFS）
  services.fwupd.enable = true;

  # syncthing GUI 密码（syncthing 服务以 fan 用户跑，owner 必须 fan 才能读；
  # 模块 guiPasswordFile 自动 bcrypt 后经 REST API 注入，不覆盖 config.xml 配对状态）
  age.secrets."syncthing-gui-password" = {
    file = tools.relative "secrets/syncthing-gui-password.age";
    path = "/run/agenix/syncthing-gui-password";
    owner = "fan";
    group = "users";
    mode = "0400";
  };

  programs.git = {
    enable = true;
    config.credential.helper = "store";
  };

  # fcitx5 中文输入法：系统层 i18n.inputMethod（NixOS 模块）自动设 IM 环境变量
  # + 生成 /etc/gtk-3.0/immodules.cache
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
  };
}
