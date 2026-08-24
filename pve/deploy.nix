# PVE 部署编排（flake packages.<host>：nix run .#<host> [ip]）
# 组装：机器层配置渲染（./<host>）+ apply/deploy 脚本（占位符替换）
# 部署目标：PVE 宿主机（Debian 13 trixie，root 用户）
# HM activation 在目标机本机构建（darwin 无法构建 x86_64-linux 闭包），见 deploy.sh
# 注意：flake.nix 里 import 本文件时传 host = "ds2" / "desktop" 等
{ pkgs, lib, host }:
let
  cfg = import ./${host} { inherit pkgs lib; };
  # fan 专属：tailscale state 从 secrets 解密推送（其他机器 tsState 为空 → 两段均为空）
  tsState = if cfg ? tailscaleState then toString cfg.tailscaleState else "";
  tsPush = if tsState != "" then ''
    echo "==> [4.5/5] 推送 tailscale state（fan 专属：secrets 解密 → scp）"
    if [ -f "${tsState}" ]; then
      age -d -i "$HOME/.secrets/age-keys.txt" "${tsState}" > /tmp/ts-state
      scp -q /tmp/ts-state root@$HOST:/tmp/tailscale-state
      rm -f /tmp/ts-state
      echo "tailscale state 已推送（fan 身份归档）"
    else
      echo "警告: tailscale state 文件缺失（${tsState}）" >&2
    fi
  '' else "";
  tsApply = if tsState != "" then builtins.readFile ./tailscale-apply.sh else "";
  applySh = pkgs.writeShellScript "${host}-apply" (builtins.replaceStrings
    [ "@PVE_ASSIST_BASE@" "@TAILSCALE@" ]
    [ cfg.pveAssistBase tsApply ]
    (builtins.readFile ./apply.sh));
in
pkgs.writeShellScriptBin "${host}-deploy" (builtins.replaceStrings
  [ "@FILES@" "@APPLY@" "@HOST@" "@TS_PUSH@" ]
  [ "${cfg.files}" "${applySh}" host tsPush ]
  (builtins.readFile ./deploy.sh))
