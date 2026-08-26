# 容器通用配置（isContainer=true 的机器生效，如多台 ide 开发容器）
# 身份与 reloadSystemd 由 identity.nix 统一；本文件只处理旧镜像文件接管。

{
  lib,
  isContainer ? false,
  ...
}:
{
  # 旧镜像构建期写过 ~/.zshrc ~/.zshenv（Dockerfile 已改写到 /etc/zsh/zshenv，新镜像无此文件）：
  # HM 的 programs.zsh 要接管这两个文件，force 覆盖旧镜像残留；新镜像 force 无副作用。
  # 键必须带 "./" 前缀与 HM zsh 模块对齐（dotDirRel），否则会生成孤立条目。
  home.file."./.zshrc".force = lib.mkIf isContainer true;
  home.file."./.zshenv".force = lib.mkIf isContainer true;
}
