# nix-pve 用户层机器微调；公共/平台层由 home/fan/module-list.nix 注入。
{ tools, lib, ... }:
{
  imports = tools.scan ./.;

  # nix-pve 是 PVE 上的 VM，无中文聊天需求（微信/QQ 由 modules/home/chat.nix 在 NixOS 平台默认开）
  # 且其 extraUnfree 未放行 wechat/qq，若开启会 eval 失败
  softwares.chat.enable = lib.mkForce false;
  softwares.pi.enable = true;
}
