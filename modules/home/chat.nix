# 中文聊天软件（微信 / QQ）：NixOS 真机桌面默认装，其余平台（容器 / mac / PVE）默认不装
# 微信：nixpkgs 的版本停在 4.1.1.8（web.archive 归档 2026-08-18），官方 Linux 版已到
#   4.1.13.26 —— 服务端按新版校验，旧版登录即提示「版本过低」，故用官方 AppImage 自建
#   （升级 = 改 version + 重取 hash：nix store prefetch-file <官方 URL>；同 clashx-meta 模式）
# QQ：26.05 的 3.2.29 源 URL 已死（404），用 unstable 通道的 3.2.32（→ overlays/unstable.nix）
# unfree：由机器注册表 tools/machines.nix 的 extraUnfree 放行（wechat / qq）；未声明的机器
#   若开启本模块会 eval 失败（extraUnfree 未放行 wechat/qq）
# 启用：默认仅 NixOS 平台开启；某台不装 → 机器层 softwares.chat.enable = lib.mkForce false

{
  config,
  lib,
  pkgs,
  platform,
  ...
}:
{
  options.softwares.chat.enable = lib.mkEnableOption "中文聊天软件（微信 / QQ）" // {
    default = platform == "nixos";
  };

  config = lib.mkIf config.softwares.chat.enable {
    home.packages = with pkgs; [
      # 微信 4.x Linux（官方最新，覆盖 nixpkgs 的 4.1.1.8）
      (callPackage "${pkgs.path}/pkgs/by-name/we/wechat/linux.nix" {
        pname = "wechat";
        version = "4.1.13.26";
        src = fetchurl {
          url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
          hash = "sha256-RSYYC8qYASh5FZmvEi/0eVACpXFaUQ9qZUgOK+aHQkQ=";
        };
        meta = wechat.meta;
      })
      repos.unstable.qq
    ];
  };
}
