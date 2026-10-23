# nix-im（Lenovo ThinkBook 14 G6+ IMH 笔记本，953.9G NVMe + Intel Core Ultra 5 125H/Arc 核显 + KDE Plasma 桌面）—— 机器组装清单
# 公共配置在 hosts/_common_/ + hosts/_nixos_/，本目录只放本机特有项
# 与 nix-lenovo 是同一套机型的 AMD/Intel 两版：imports 清单逐字相同，差异只在
#   hostName、hardware.nix（Intel 微码/核显）、secrets/hosts/nix-im/（ssh 主机密钥与 fan 密码
#   有意与 nix-lenovo 共用同一份密文）、Syncthing 设备身份（装好后补 tools/syncthingPeers.nix）
# 部署：手动 nixos-rebuild switch --flake .#nix-im（笔记本移动设备）
#   首次安装：nixos-install --flake /persist/etc/nixos#nix-im（仓库放 /persist/etc/nixos）
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
      "hosts/_nixos_/services/syncthing.nix"
      "hosts/_nixos_/services/tailscale.nix"

      "users/fan"
    ]
    ++ (tools.scan ./.);

  # 身份键：hosts/_nixos_/base/keys.nix 与 password.nix 按此名取 secrets/hosts/<名>/ 下的密文
  networking.hostName = "nix-im";

  # Wayland 默认会话（无 RustDesk 被控需求，无需 X11 妥协；RustDesk 仅作 client 远程其他机器）
  services.xserver.enable = false;

  # nix 下载走国内镜像（手动 rebuild 用；root 的 nix.conf 由 NixOS 生成，天然 trusted）
  nix.settings.substituters = tools.config.nixSubstituters;
  nix.settings.extra-substituters = tools.config.nixCachixSubstituters;
  nix.settings.extra-trusted-public-keys = tools.config.nixCachixTrustedPublicKeys;

  # 本地构建：sandbox=true 时部分包构建受限，关沙箱换构建可行
  nix.settings.sandbox = false;

  # store 自动 GC（953.9G 盘，30 天保留）+ 定期硬链接优化
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

  # Switch 模拟器 eden 的手柄支持：包自带 72-yuzu-input.rules（Pro Controller / Joy-Con 的 hidraw uaccess），
  # NixOS 只认 services.udev.packages，不注入则手柄静默不可用
  services.udev.packages = [ pkgs.eden ];

  # 蓝牙 Pro 手柄：hid_nintendo 在蓝牙下初始化必超时（nix-lenovo 上复现两次），
  # probe 失败即无驱动接管 → 既无 /dev/input/js* 也无 /dev/hidraw*，Eden/SDL 一概看不到。
  # 禁用该模块，让 hid-generic 接管：USB 与蓝牙统一成标准 HID 手柄（SDL 自带 Switch Pro
  # 驱动，可给正确映射/陀螺仪/震动）。要回退内核驱动：删本行 + nixos-rebuild 后重启。
  boot.blacklistedKernelModules = [ "hid_nintendo" ];

  # eden 自带规则里蓝牙那条用 KERNELS=="*057e:2009*"（小写），而内核设备名是 057E:2009（大写），
  # 匹配不到 → hidraw 停在 0600 root:root，用户态（SDL hidapi / Eden 手柄驱动）打不开。
  # 另：蓝牙设备挂在 virtual/uhid 下，systemd 的 uaccess 判不出 seat，ACL 不会下发，故用组权限兜底。
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", KERNELS=="*057E:2009*", MODE="0660", GROUP="users"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", KERNELS=="*057E:2006*", MODE="0660", GROUP="users"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", KERNELS=="*057E:2007*", MODE="0660", GROUP="users"

    # F1-F12 直出为功能键，Fn+F1-F12 才是多媒体/热键（SALS_FNLOCK_ON）。
    # ideapad_laptop 模块没有 fn_lock 模块参数，只能在设备出现时写 sysfs 属性；
    # EC 是否跨重启记忆不保证，故每次 add 事件都写（幂等）。
    ACTION=="add", SUBSYSTEM=="platform", KERNEL=="VPC2004:00", ATTR{fn_lock}="1"
  '';

  # 蓝牙（NixOS 默认不开；Intel CNVi 的蓝牙硬件在，KDE 界面已就位，蓝牙耳机/键鼠刚需）
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # 无 WWAN 模块，ModemManager 纯耗资源，禁用（26.05 起选项为 networking.modemmanager）
  networking.modemmanager.enable = false;

  # 固件更新（BIOS/EC，Linux Vendor Firmware Service；Lenovo 等品牌靠它）
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
  # （SDDM 图形会话 source /etc/profile 生效，home-manager sessionVariables 只进 ~/.zshenv 不覆盖图形会话）
  # + 生成 /etc/gtk-3.0/immodules.cache（GTK 默认查找路径；fcitx5-with-addons 含 fcitx5-gtk immodule）
  # 用户层 fcitx5 配置（全拼/皮肤）由 home/fan/_nixos_/i18n/zh-CN/fcitx.nix 管理
  # addons 与 home 层同 list → 系统/用户 profile 的 fcitx5-with-addons 为同一 drv，只存一份
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = [ pkgs.kdePackages.fcitx5-chinese-addons ];
    fcitx5.waylandFrontend = true;
  };
}
