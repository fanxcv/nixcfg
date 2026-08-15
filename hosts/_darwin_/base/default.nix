# macOS 系统层公共模块（nix-darwin）
# 模块自动扫描：新增 .nix 文件即生效（tools.scan）
# 结构对应原仓库 hosts/_darwin_/：base（homebrew/系统基础）+ gui（quartz 桌面声明）
# + i18n（字体）+ kernel（电源/启动）+ services（tailscale 等）

{
  inputs,
  outputs,
  tools,
  ...
}:
{
  imports = (tools.scan ./.) ++ [
    outputs.darwinModules.default                 # 自建 darwin 系统模块库（modules/darwin/：nix 配置等）
    inputs.agenix.darwinModules.default        # secrets 解密（身份见 hosts/_common_/base/agenix.nix）
    inputs.home-manager.darwinModules.home-manager  # home-manager 内嵌（用户见 users/fan）
    inputs.nix-homebrew.darwinModules.nix-homebrew  # homebrew 声明式管理
  ];

  system.stateVersion = 7;

  # 部署遇已存在手配文件（.zshrc/.npmrc/.claude 等）自动备份为 <file>.backup 再接管
  # （不能用环境变量 HOME_MANAGER_BACKUP_EXT：别名脚本经 sudo env_reset 会清掉；
  #   此选项由 nix-darwin 在 launchctl asuser 激活链内注入，见 home-manager 模块源码）
  home-manager.backupFileExtension = "backup";
}
