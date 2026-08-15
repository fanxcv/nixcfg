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

  # nix 下载走国内镜像（comin 部署/手动 rebuild 用；root 的 nix.conf 由 NixOS 生成，天然 trusted）
  nix.settings.substituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://mirror.sjtu.edu.cn/nix-channels/store"
    "https://cache.nixos.org/"
  ];

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
  age.secrets."comin-token" = {
    file = tools.relative "secrets/comin-token.age";
    path = "/run/agenix/comin-token";
    mode = "0400";
  };

  programs.git = {
    enable = true;
    config.credential.helper = "store";
  };
}
