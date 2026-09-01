# 用户身份与 Home Manager 全局路径策略（所有平台共用）
# container / pve / ubuntu（云服务器 root 登录）使用 root 且没有 user systemd；其他平台使用 fan。
{
  lib,
  platform ? "nixos",
  isContainer ? false,
  ...
}:
let
  isRootHome = isContainer || platform == "pve" || platform == "ubuntu";
  userName = if isRootHome then "root" else "fan";
  homeDirectory =
    if isRootHome then
      "/root"
    else if platform == "darwin" then
      "/Users/fan"
    else
      "/home/fan";
in
{
  home.username = userName;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "25.05";

  # 容器与 PVE 没有用户级 systemd，避免 Home Manager 激活时重复警告。
  home.activation.reloadSystemd = lib.mkIf isRootHome (
    lib.mkForce (lib.hm.dag.entryAfter [ "linkGeneration" ] "")
  );
}
