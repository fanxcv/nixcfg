# 容器通用配置（isContainer=true 的机器生效，如多台 ide 开发容器）
# 容器挂载/SSH 全是 /root 语义，覆盖平台默认用户（nixos 默认 fan → root）
# 原在 ide/default.nix，多台容器部署提取为共享模块，机器目录只需留空占位

{ pkgs, lib, isContainer ? false, ... }:
{
  home.username = lib.mkIf isContainer (lib.mkForce "root");
  home.homeDirectory = lib.mkIf isContainer (lib.mkForce "/root");

  # 旧镜像构建期写过 ~/.zshrc ~/.zshenv（Dockerfile 已改写到 /etc/zsh/zshenv，新镜像无此文件）：
  # HM 的 programs.zsh 要接管这两个文件，force 覆盖旧镜像残留；新镜像 force 无副作用
  home.file.".zshrc".force = lib.mkIf isContainer true;
  home.file.".zshenv".force = lib.mkIf isContainer true;
}
