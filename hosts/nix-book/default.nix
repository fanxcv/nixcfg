# nix-book（无界14S 笔记本，476.9G NVMe + AMD 7840HS/780M 核显 + KDE Plasma 桌面）—— 机器组装清单
# 公共配置在 hosts/_common_/ + hosts/_nixos_/，本目录只放本机特有项
# 部署：手动 nixos-rebuild switch --flake .#nix-book（笔记本移动设备，不用 comin 自动部署）
#   首次安装：nixos-install --flake /persist/etc/nixos#nix-book（仓库放 /persist/etc/nixos）
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

      "users/fan"
    ]
    ++ (tools.scan ./.);

  networking.hostName = "nix-book";

  # Wayland 默认会话（无 RustDesk 被控需求，无需 X11 妥协；RustDesk 仅作 client 远程其他机器）
  services.xserver.enable = false;

  # SDDM 自动登录 fan：开机直进桌面（笔记本自用，无锁屏风险可接受）
  services.displayManager.autoLogin = {
    enable = true;
    user = "fan";
  };

  # nix 下载走国内镜像（手动 rebuild 用；root 的 nix.conf 由 NixOS 生成，天然 trusted）
  nix.settings.substituters = tools.config.nixSubstituters;
  nix.settings.extra-substituters = tools.config.nixCachixSubstituters;
  nix.settings.extra-trusted-public-keys = tools.config.nixCachixTrustedPublicKeys;

  # 本地构建：sandbox=true 时部分包构建受限，关沙箱换构建可行
  nix.settings.sandbox = false;

  # store 自动 GC（476G 盘，30 天保留）+ 定期硬链接优化
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

  programs.git = {
    enable = true;
    config.credential.helper = "store";
  };

  # fcitx5 中文输入法：系统层 i18n.inputMethod（NixOS 模块）自动设 IM 环境变量
  # （SDDM 图形会话 source /etc/profile 生效，home-manager sessionVariables 只进 ~/.zshenv 不覆盖图形会话）
  # + 生成 /etc/gtk-3.0/immodules.cache（GTK 默认查找路径；fcitx5-with-addons 含 fcitx5-gtk immodule）
  # 用户层 fcitx5 配置（双拼/皮肤）由 home/fan/_nixos_/i18n/zh-CN/fcitx.nix 管理
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
  };
}
