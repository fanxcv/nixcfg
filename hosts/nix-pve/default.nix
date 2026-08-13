# nix-pve（Proxmox VE 上的 NixOS 虚拟机，128G 盘 + KDE Plasma 桌面）—— 机器组装清单
# 公共配置在 hosts/_common_/ + hosts/_nixos_/，本目录只放本机特有项
# 部署：手动 nixos-rebuild switch --flake .#nix-pve
#   （comin 自动部署未启用；需要时 import "hosts/_nixos_/services/comin.nix"）
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

      "users/fan"
    ]
    ++ (tools.scan ./.);

  networking.hostName = "nix-pve";
}
