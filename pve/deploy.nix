# ds2 部署编排（flake packages.ds2：nix run .#ds2 [host]）
# 组装：系统配置渲染（./ds2）+ apply/deploy 脚本（占位符替换）
# 部署目标：PVE 9.2 宿主机（Debian 13 trixie，root 用户）
# HM activation 在 ds2 本机构建（darwin 无法构建 x86_64-linux 闭包），见 deploy.sh [3/5]
{ pkgs, lib, ... }:
let
  cfg = import ./ds2 { inherit pkgs lib; };
  applySh = pkgs.writeShellScript "ds2-apply" (builtins.replaceStrings
    [ "@PVE_ASSIST_BASE@" ]
    [ cfg.pveAssistBase ]
    (builtins.readFile ./ds2/apply.sh));
in
pkgs.writeShellScriptBin "ds2-deploy" (builtins.replaceStrings
  [ "@FILES@" "@APPLY@" ]
  [ "${cfg.files}" "${applySh}" ]
  (builtins.readFile ./deploy.sh))
