# NixOS 平台公共模块（nix-pve 接入后生效，接入步骤见 hosts/README.md）
# imports 自动扫描：本目录 + ./services 下新增 .nix 文件即生效（tools.scan）
# 机器层只需 import 本目录（hosts/<host>/default.nix），模块全部自动挂载

{
  inputs,
  outputs,
  tools,
  ...
}:
{
  imports = (tools.scan ./.) ++ [
    outputs.nixosModules.default # 自建 nixos 系统模块库（modules/nixos/，当前空）
    inputs.disko.nixosModules.disko # 声明式磁盘分区（hosts/<host>/disks.nix）
    inputs.comin.nixosModules.comin # git 驱动自动部署（按机器启用 services/comin.nix）
    inputs.agenix.nixosModules.default # 密钥解密（secrets/*.age，identity 见 hosts/_common_/base/agenix.nix）
    inputs.impermanence.nixosModules.impermanence # 不可变系统（/persist 持久化，见 hosts/<host>/immutable.nix）
    inputs.home-manager.nixosModules.home-manager # 用户层（users/fan 挂载 home/fan/<host>）
    inputs.catppuccin.nixosModules.catppuccin # Catppuccin 系统级主题（sddm/grub/plymouth，见 hosts/_nixos_/themes/）
  ];

  system.stateVersion = "25.05";

  # mihomo 用户服务（home/fan/_nixos_/mihomo.nix）要开机自启而非等登录：
  # 无 linger 时 user@1000 只在 fan 登录后拉起，代理在登录前不可用
  users.users.fan.linger = true;

  # /etc/nixos 仓库属主必须归 fan：nixcfg 以 fan 身份跑 git fetch/checkout/reset，
  # 而 nixos-install / 首次以 root clone 会留下 root:root（.git 与 FETCH_HEAD 不可写 →
  # git fetch 报 "cannot open '.git/FETCH_HEAD': Permission denied"）。
  # /etc/nixos 是 /persist/etc/nixos 的 bind mount，chown 真实存储即可（1424 项约 0.17s，
  # 无条件执行以自愈 root 误操留下的属主混杂）
  system.activationScripts.nixcfgRepoOwner = ''
    if [ -d /persist/etc/nixos ]; then
      chown -R fan:users /persist/etc/nixos
    fi
  '';
}
