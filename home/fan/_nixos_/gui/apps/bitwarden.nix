# Bitwarden 桌面版：禁止开机自启（包本体见 ../apps.nix）
# 不用 nix 管 ~/.config/autostart/bitwarden.desktop：Bitwarden 每次启动都按自身状态重建它，
# 写 Hidden=true 会被覆盖；改的是它自己的状态文件（应用实体文件，见 disable-autostart.py）
{ lib, pkgs, ... }:
{
  home.activation.bitwardenDisableAutostart = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 ${./bitwarden/disable-autostart.py}
  '';
}
