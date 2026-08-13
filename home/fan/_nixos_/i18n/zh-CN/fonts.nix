# fontconfig 默认字体（用户层）：中文 Noto CJK，等宽不指定用系统默认
# 系统字体已由 hosts/_nixos_/i18n/fonts.nix 安装，这里只定默认优先级
{ pkgs, ... }:
{
  fonts.fontconfig = {
    enable = true;
    antialiasing = true;
    hinting = "full";
    subpixelRendering = "rgb";
    defaultFonts = {
      serif = [
        "Noto Serif CJK SC"
      ];
      sansSerif = [
        "Noto Sans CJK SC"
      ];
      monospace = [
        "Noto Sans Mono CJK SC"
      ];
      emoji = [
        "Noto Color Emoji"
      ];
    };
  };
}
