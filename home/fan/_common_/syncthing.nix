# syncthing 同步目录忽略规则（Mac / NixOS / ide 容器共用同一份 tools.syncthingStignore）
#   .stignore 本身被 syncthing 忽略，不跨设备同步 → 各设备须各自写入
#   ~/sync 与 ~/share 整目录持久化（NixOS immutable.nix），.stignore 随目录持久
# 门控：容器由 _container_/syncthing.nix 的 install 脚本自写、PVE 主机本无 syncthing → 只覆盖原本生效的 darwin/nixos
{
  lib,
  tools,
  platform,
  ...
}:
lib.mkIf (platform == "darwin" || platform == "nixos") {
  home.file."sync/.stignore".text = tools.syncthingStignore;
  home.file."share/.stignore".text = tools.syncthingStignore;
}
