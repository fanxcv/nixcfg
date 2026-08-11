# NixOS 服务集合（等第一台真机接入后生效）
# 新增服务：新建 .nix 文件并在下方 import（或改用 tools.scan 自动导入）

{
  imports = [
    ./comin.nix  # git 驱动自动部署
  ];
}
