# PVE 机器配置构造器：公共值来自 ./default.nix，机器文件只声明差异。
{
  pkgs,
  lib,
  hostName,
  ip,
  gateway ? null,
  modprobeHost ? { },
  extra ? [ ],
  tailscaleForward ? false,
  tailscaleState ? null,
  luckyData ? null,
  hpExtra ? null,
  miExtra ? null,
}:
let
  common = import ./default.nix;
  dns = common.dns;
  mirror = common.mirror;
  suite = common.suite;
  modprobePublic = common.modprobePublic;
  grubCmdline = common.grubCmdline ++ extra;
  effectiveGateway = if gateway == null then common.gateway else gateway;
  attrs = {
    inherit
      hostName
      ip
      modprobeHost
      tailscaleForward
      ;
    inherit (common)
      dns
      mirror
      pveAssistBase
      suite
      modprobePublic
      ;
    gateway = effectiveGateway;
    inherit grubCmdline;
    files = import ./render.nix {
      inherit
        pkgs
        lib
        dns
        mirror
        suite
        grubCmdline
        modprobePublic
        modprobeHost
        tailscaleForward
        ip
        ;
      gateway = effectiveGateway;
    };
  };
in
attrs
// lib.optionalAttrs (tailscaleState != null) { inherit tailscaleState; }
// lib.optionalAttrs (luckyData != null) { inherit luckyData; }
// lib.optionalAttrs (hpExtra != null) { inherit hpExtra; }
// lib.optionalAttrs (miExtra != null) { inherit miExtra; }
