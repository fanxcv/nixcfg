# 桌面应用（nix-im 笔记本，与 nix-lenovo 一致）：mpv（VAAPI 硬解）+ eden（Switch 模拟器）+ python3
# 微信/QQ 已上提到 modules/home/chat.nix（softwares.chat 门控，所有 NixOS 真机默认装）
# 硬解：Arc 核显走 iHD 驱动（hardware.graphics.extraPackages 已加 intel-media-driver），mpv.conf hwdec=vaapi
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mpv
    # Eden 官方不推荐 Wayland（多数合成器下性能显著更差 + 神秘 bug），包装脚本固定 xcb；
    # 用 --set-default 而非 --set，用户显式另指平台时仍可覆盖
    (eden.overrideAttrs (prev: {
      preFixup = prev.preFixup + ''
        qtWrapperArgs+=(--set-default QT_QPA_PLATFORM xcb)
      '';
    }))
    python3
  ];
}
