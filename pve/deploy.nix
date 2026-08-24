# PVE 部署编排（flake packages.<host>：nix run .#<host> [ip]）
# 组装：机器层配置渲染（./<host>）+ apply/deploy 脚本（占位符替换）
# 部署目标：PVE 宿主机（Debian 13 trixie，root 用户）
# HM activation 在目标机本机构建（darwin 无法构建 x86_64-linux 闭包），见 deploy.sh
# 注意：flake.nix 里 import 本文件时传 host = "ds2" / "desktop" 等
{ pkgs, lib, host }:
let
  cfg = import ./${host} { inherit pkgs lib; };
  applySh = pkgs.writeShellScript "${host}-apply" (builtins.replaceStrings
    [ "@PVE_ASSIST_BASE@" ]
    [ cfg.pveAssistBase ]
    (builtins.readFile ./apply.sh));
in
pkgs.writeShellScriptBin "${host}-deploy" (builtins.replaceStrings
  [ "@FILES@" "@APPLY@" "@HOST@" ]
  [ "${cfg.files}" "${applySh}" host ]
  (builtins.readFile ./deploy.sh))
