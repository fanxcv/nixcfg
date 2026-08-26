# Home Manager 模块统一装配：所有入口共用同一套层次。
# 返回顺序：跨平台公共层、平台层、可选机器层；调用方另加 home/fan/default.nix。
{
  lib,
  self,
  platform,
  hostName,
}:
let
  homeRoot = self + "/home/fan";
  platformDir = homeRoot + "/_${platform}_";
  hostDir = homeRoot + "/${lib.strings.toLower hostName}";
in
[
  (homeRoot + "/_common_")
  platformDir
]
++ lib.optional (builtins.pathExists hostDir) hostDir
