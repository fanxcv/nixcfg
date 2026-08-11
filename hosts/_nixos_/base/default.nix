# NixOS 平台公共模块——等第一台真机接入后生效（接入步骤见 hosts/README.md）
# flake.nix 需同时注册 nixosConfigurations（README 有完整示例）
# imports 自动扫描：本目录 + ./services 下新增 .nix 文件即生效（tools.scan）

{
  inputs,
  tools,
  ...
}:
{
  imports = (tools.scan ./.) ++ [
    inputs.comin.nixosModules.comin  # git 驱动自动部署（仓库地址见 services/comin.nix）
  ];

  # 真机接入后按需补：users.users / services.openssh / system.stateVersion 等
}
