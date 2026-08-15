# NixOS 系统服务：docker（声明式，开机自启；home 层 activation 只负责 dc 软链/network fan）
# 国内镜像加速（挂 useChinaMirror 开关，flake.nix specialArgs 注入，与 mac orbstack/mirrors.nix 同语义）：
#   true  → daemon.settings.registry-mirrors 三镜像；false → 不设，docker daemon 默认源
{ pkgs, lib, useChinaMirror ? true, ... }:
{
  virtualisation.docker = {
    enable = true;
    daemon.settings = lib.mkIf useChinaMirror {
      registry-mirrors = [
        "https://docker.xuanyuan.me"
        "https://docker.1ms.run"
        "https://docker.m.daocloud.io"
      ];
    };
  };
}
