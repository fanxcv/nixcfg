# 桌面应用（nix-lenovo 笔记本）：微信/QQ（unfree，flake extraUnfree 已放行）+ mpv（VAAPI 硬解）+ eden（Switch 模拟器）+ python3
# 硬解：780M 核显 vcn 解码 ring 已就位（dmesg 验证），mpv.conf hwdec=vaapi 走核显省电
{ pkgs, ... }:
let
  # nixpkgs 的 wechat 停在 4.1.1.8（web.archive 归档 2026-08-18），官方 Linux 版已到
  # 4.1.13.26（2026-10-12）——服务端按新版校验，旧版登录即提示“版本过低”。
  # 官方下载 URL 固定但内容随版本变，故升级 = 改 version + 重取 hash
  # （nix store prefetch-file <官方 AppImage URL>；同 clashx-meta 的手动升级模式）
  wechatLatest = pkgs.callPackage "${pkgs.path}/pkgs/by-name/we/wechat/linux.nix" {
    pname = "wechat";
    version = "4.1.13.26";
    src = pkgs.fetchurl {
      url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
      hash = "sha256-RSYYC8qYASh5FZmvEi/0eVACpXFaUQ9qZUgOK+aHQkQ=";
    };
    meta = pkgs.wechat.meta;
  };
in
{
  home.packages = with pkgs; [
    wechatLatest # 微信 4.x Linux（官方最新，覆盖 nixpkgs 的 4.1.1.8）
    repos.unstable.qq # QQ：26.05 的 3.2.29 源 URL 已死（404），unstable 3.2.32 可用（→ overlays/unstable.nix）
    mpv # 视频播放（VAAPI 硬解）
    eden # Switch 模拟器（Yuzu/Sudachi 后继；手柄 hidraw 规则经 hosts/nix-lenovo/default.nix 的 services.udev.packages 注入）
    # Python 3.13 + pip：nixpkgs 的 python3 以 --without-ensurepip 构建，裸装无 pip（连 ensurepip 也无）
    (python3.withPackages (ps: [ ps.pip ]))
  ];

  # mpv VAAPI 硬解配置（780M：vcn_4_0_2 解码；vaapi 失败自动回退软解）
  home.file.".config/mpv/mpv.conf".text = ''
    hwdec=vaapi
    vo=gpu-next
  '';
}
