# NixOS 系统服务：docker（声明式，开机自启；home 层 activation 只负责 dc 软链/network fan）
{ pkgs, ... }:
{
  virtualisation.docker.enable = true;
}
