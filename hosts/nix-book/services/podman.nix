# NixOS 系统服务：podman（nix-book 照搬 nix-pve；docker CLI/socket 兼容，drop-in 替换 docker）
# 国内镜像加速（挂 useChinaMirror 开关，flake.nix specialArgs 注入，与 mac orbstack/mirrors.nix 同语义）：
#   true  → registries.conf.d 三镜像；false → 不设，podman 默认源
{
  pkgs,
  lib,
  tools,
  useChinaMirror ? true,
  ...
}:
let
  registryMirrors = lib.concatMapStringsSep "\n" (mirror: ''
    [[registry.mirror]]
    location = "${lib.strings.removePrefix "https://" mirror}"
  '') tools.config.dockerRegistryMirrors;
in
{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # docker 命令别名 → podman（drop-in 替换）
    dockerSocket.enable = true; # /var/run/docker.sock → podman.sock（compose 等工具兼容）
  };

  # podman 组（rootless 容器 + docker.sock 访问；模块不自动创建，fan 用户 extraGroups 依赖）
  users.groups.podman = { };

  # 镜像加速：docker.io → 国内三镜像（与 docker daemon.json 同 3 域名）
  environment.etc."containers/registries.conf.d/mirror.conf" = lib.mkIf useChinaMirror {
    text = ''
            [[registry]]
            location = "docker.io"
      ${registryMirrors}
    '';
  };
}
