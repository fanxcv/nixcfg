# macOS 系统层公共模块（nix-darwin）
# 模块自动扫描：新增 .nix 文件即生效（tools.scan）
# 结构对应原仓库 hosts/_darwin_/：base（homebrew/系统基础）+ gui（quartz 桌面声明）
# + i18n（字体）+ kernel（电源/启动）+ services（tailscale 等）

{
  inputs,
  tools,
  ...
}:
{
  imports = (tools.scan ./.) ++ [
    inputs.agenix.darwinModules.default        # secrets 解密（身份见 hosts/_common_/base/agenix.nix）
    inputs.home-manager.darwinModules.home-manager  # home-manager 内嵌（用户见 users/fan）
    inputs.nix-homebrew.darwinModules.nix-homebrew  # homebrew 声明式管理
  ];

  system.stateVersion = 7;
}
