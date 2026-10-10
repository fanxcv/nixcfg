# AI 工具二进制模块（从 _common_/ai.nix 迁入，加 softwares.ai.enable 门控）：dolt
# beads（bd）不归 nix 管：由 fpi-install 经 npm 装（@beads/bd），其 Dolt 后端由本模块提供
# 其他 AI 工具各归各文件：codex → codex.nix，pi → pi.nix
# 启用：本模块默认 enable=true；某台不装 → 机器层 softwares.ai.enable = lib.mkForce false

{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.softwares.ai.enable = lib.mkEnableOption "AI 工具二进制（dolt）" // {
    default = true;
  };

  config = lib.mkIf config.softwares.ai.enable {
    # beads（npm 装的 bd）以 Dolt 为存储后端（嵌入式/独立 server 均需 dolt CLI 管理）
    home.packages = [
      pkgs.dolt
    ];
  };
}
