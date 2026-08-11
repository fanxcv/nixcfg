# 容器通用配置（isContainer=true 的机器生效，如多台 ide 开发容器）
# 容器挂载/SSH 全是 /root 语义，覆盖平台默认用户（nixos 默认 fan → root）
# 原在 ide/default.nix，多台容器部署提取为共享模块，机器目录只需留空占位

{ pkgs, lib, isContainer ? false, ... }:
{
  home.username = lib.mkIf isContainer (lib.mkForce "root");
  home.homeDirectory = lib.mkIf isContainer (lib.mkForce "/root");
}
