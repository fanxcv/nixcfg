# 跨平台共享配置（所有机器通用）——对应 nixcfg 的 home/tsln/_common_/
# 改这里 = 所有机器同步生效
# 模块自动扫描（tools.scan）：本目录 .nix 文件全量导入，新增文件即生效
#   当前清单：identity.nix / base.nix / container.nix / mirrors.nix / path.nix / secrets.nix / shells.nix
#   （软件类已全部迁入 modules/home/：codex/pi/tmux/ai/mise/ssh；claude 已并入 ai.nix）
# 软件模块库（modules/home/，每个软件一个文件 + softwares.<名>.enable 门控）：
#   各模块自述默认值：tmux/mise/ssh 默认开（某台不装 → 机器层 softwares.<名>.enable = lib.mkForce false）
#   codex/pi/ai 默认关（保留机在机器层显式 softwares.pi.enable = true，ai 跟随 pi）
# 另含 vscode 封装（modules/home/vscode.nix：容器同吃但模块默认关闭，平台层按需启用）

{
  tools,
  outputs,
  inputs,
  config,
  ...
}:
{
  imports = (tools.scan ./.) ++ [
    outputs.homeModules.default
    inputs.catppuccin.homeModules.catppuccin
    # plasma-manager 挂全平台（tsln 同款）：darwin/容器也持有 programs.plasma options，
    # 避免 modules/home/catppuccin/plasma.nix 在非 NixOS 平台 eval undefined
    inputs.plasma-manager.homeModules.plasma-manager
  ];
}
