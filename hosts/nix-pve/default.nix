# nix-pve（Proxmox VE 上的 NixOS 虚拟机，128G 盘 + KDE Plasma 桌面）—— 机器组装清单
# 公共配置在 hosts/_common_/ + hosts/_nixos_/，本目录只放本机特有项
# 部署：comin 自动部署（git.fan-x.fun 仓库轮询，见 services/comin.nix）；
#   首次接入手动：nixos-rebuild switch --flake /etc/nixos#nix-pve（仓库放 /persist/etc/nixos）
{ tools, ... }:
{
  imports =
    map tools.relative [
      "hosts/_common_/base"
      "hosts/_common_/i18n"
      "hosts/_nixos_/base"
      "hosts/_nixos_/i18n"
      "hosts/_nixos_/gui/desktop/plasma.nix"
      "hosts/_nixos_/services/openssh.nix"
      "hosts/_nixos_/services/comin.nix"

      "users/fan"
    ]
    ++ (tools.scan ./.);

  networking.hostName = "nix-pve";

  # 默认会话切 X11（plasmax11）：RustDesk 在 KDE Plasma 6 Wayland 下 capturer 报错
  # （上游 bug #13374/#13378，portal 预授权无效，1.4.9 未修）；X11 会话 RustDesk 捕获稳定
  services.displayManager.defaultSession = "plasmax11";
  # X11 会话需要 Xorg（plasma6 模块默认只启 Wayland，不自动开 xserver）
  services.xserver.enable = true;

  # nix 下载走国内镜像（comin 部署/手动 rebuild 用；root 的 nix.conf 由 NixOS 生成，天然 trusted）
  nix.settings.substituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://cache.nixos.org/"
  ];

  # 本地 VM 构建：sandbox=true 时部分包构建受限，关沙箱换构建可行
  nix.settings.sandbox = false;

  # store 自动 GC（128G 盘，30 天保留）+ 定期硬链接优化
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 30d";
  nix.optimise.automatic = true;

  # virtio 盘定期 trim（SSD 寿命/性能）
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # fan sudo 免密（日常维护/手动 rebuild 用）
  security.sudo.wheelNeedsPassword = false;

  # comin 拉取私有仓库的凭据：复用 git-credentials.age → /root/.git-credentials
  # （git 的 credential.helper=store 读该文件，见下方 programs.git）
  age.secrets."root/git-credentials" = {
    file = tools.relative "secrets/git-credentials.age";
    path = "/root/.git-credentials";
    mode = "0600";
  };

  # comin 的 go-git 认证 token（见 services/comin.nix 的 auth.access_token_path）
  # 机器独有（mini-m4 实验机共用同一 token，跨引用此文件）
  age.secrets."comin-token" = {
    file = tools.relative "secrets/hosts/nix-pve/comin-token.age";
    path = "/run/agenix/comin-token";
    mode = "0400";
  };

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
}
