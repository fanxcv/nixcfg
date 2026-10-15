# syncthing 同步目录忽略规则（Mac / NixOS / ide 容器共用同一份 tools.syncthingStignore）
#   .stignore 本身被 syncthing 忽略，不跨设备同步 → 各设备须各自写入
#   ~/sync 与 ~/share 整目录持久化（immutable.nix），.stignore 随目录持久
{ tools, ... }:
{
  home.file."sync/.stignore".text = tools.syncthingStignore;
  home.file."share/.stignore".text = tools.syncthingStignore;
}
