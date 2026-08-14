# nixos 系统层模块库（tsln 的 modules/nixos 思路）：平台通用系统模块
# 被 hosts/_nixos_/base/default.nix 引用（outputs.nixosModules.default）
# 当前无模块：未来服务/虚拟化等通用模块放这里（如 tsln 的 hysteria/rclone/podman），按需迁移
{ tools, ... }:
{
  imports = tools.scan ./.;
}
