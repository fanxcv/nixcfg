# 桌面应用（nix-lenovo 笔记本）：mpv（VAAPI 硬解）+ eden（Switch 模拟器）+ python3
# 微信/QQ 已上提到 modules/home/chat.nix（softwares.chat 门控，所有 NixOS 真机默认装）
# 硬解：780M 核显 vcn 解码 ring 已就位（dmesg 验证），mpv.conf hwdec=vaapi 走核显省电
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mpv # 视频播放（VAAPI 硬解）
    # Switch 模拟器（Yuzu/Sudachi 后继；手柄 hidraw 规则经 hosts/nix-lenovo/default.nix 的 services.udev.packages 注入）
    # Eden 官方不推荐 Wayland（多数合成器下性能显著更差 + 神秘 bug），包装脚本固定 xcb；
    # 用 --set-default 而非 --set，用户显式另指平台时仍可覆盖
    (eden.overrideAttrs (prev: {
      preFixup = prev.preFixup + ''
        qtWrapperArgs+=(--set-default QT_QPA_PLATFORM xcb)
      '';
    }))
    # Python 3.13 + pip：nixpkgs 的 python3 以 --without-ensurepip 构建，裸装无 pip（连 ensurepip 也无）
    (python3.withPackages (ps: [ ps.pip ]))
  ];

  # mpv VAAPI 硬解配置（780M：vcn_4_0_2 解码；vaapi 失败自动回退软解）
  home.file.".config/mpv/mpv.conf".text = ''
    hwdec=vaapi
    vo=gpu-next
  '';
}
