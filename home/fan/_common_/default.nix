# 跨平台共享配置（所有机器通用）——对应 nixcfg 的 home/tsln/_common_/
# 改这里 = 所有机器同步生效
# 模块自动扫描（tools.scan）：本目录 .nix 文件全量导入，新增文件即生效
#   当前清单：base.nix / ai.nix / codex.nix / container.nix / mise.nix /
#   pi.nix / secrets.nix / shells.nix / ssh.nix / tmux.nix
#   （docker.nix 已迁至 ../_linux_/）
# 另引入自建 home 模块库（modules/home/：vscode 封装等；容器同吃但模块默认关闭，平台层按需启用）

{ tools, outputs, ... }:
{
  imports = (tools.scan ./.) ++ [
    outputs.homeModules.default
  ];
}
