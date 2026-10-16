# Home Manager 模块统一装配：所有入口共用同一套层次。
# 返回顺序：跨平台公共层、平台层、可选机器层；调用方另加 home/fan/default.nix。
# 机器层按目录扫描（tools/scan.nix 排除 default.nix）：机器目录内新增 .nix 即生效，免写样板。
{
  lib,
  self,
  platform,
  hostName,
}:
let
  # tools 不在本文件入参（调用方只传 lib/self/platform/hostName），直接取同一实现
  scan = import ../../tools/scan.nix { inherit lib; };
  homeRoot = self + "/home/fan";
  platformDir = homeRoot + "/_${platform}_";
  hostDir = homeRoot + "/${lib.strings.toLower hostName}";
in
[
  (homeRoot + "/_common_")
  platformDir
]
++ lib.optionals (builtins.pathExists hostDir) (scan hostDir)
