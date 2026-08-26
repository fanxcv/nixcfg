# 跨平台共享配置（所有机器通用）——对应 nixcfg 的 home/tsln/_common_/
# 改这里 = 所有机器同步生效
# 模块自动扫描（tools.scan）：本目录 .nix 文件全量导入，新增文件即生效
#   当前清单：base.nix / container.nix / mirrors.nix / path.nix / secrets.nix / shells.nix
#   （软件类已全部迁入 modules/home/：codex/pi/tmux/ai/mise/ssh；claude 已并入 ai.nix，见下方引用）
# 软件模块库（modules/home/，每个软件一个文件 + softwares.<名>.enable 门控）：
#   默认全开 = 所有机器默认安装；某台不装 → 机器层 softwares.<名>.enable = lib.mkForce false
# 另含 vscode 封装（modules/home/vscode.nix：容器同吃但模块默认关闭，平台层按需启用）

{ tools, outputs, config, lib, ... }:
{
  imports = (tools.scan ./.) ++ [
    outputs.homeModules.default
  ];

  # 软件默认全开（所有机器装）；机器层可 lib.mkForce false 关闭对应软件
  softwares = {
    codex.enable = lib.mkDefault true;
    pi.enable = lib.mkDefault true;
    tmux.enable = lib.mkDefault true;
    ai.enable = lib.mkDefault true;
    mise.enable = lib.mkDefault true;
    ssh.enable = lib.mkDefault true;
  };
}
