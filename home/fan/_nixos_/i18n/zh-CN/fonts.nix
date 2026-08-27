# fontconfig 默认字体（tsln 同款）：中文 Noto CJK（SC→TC→JP→KR 回退链），
# 等宽 Monaspace Neon（NF 变体）；字体包同文件安装
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
        "Noto Serif CJK TC"
        "Noto Serif CJK JP"
        "Noto Serif CJK KR"
      ];
      sansSerif = [
        "Noto Sans CJK SC"
        "Noto Sans CJK TC"
        "Noto Sans CJK JP"
        "Noto Sans CJK KR"
      ];
      monospace = [
        "Monaspace Neon"
        "Monaspace Neon NF"
      ];
      emoji = [
        "Noto Color Emoji"
      ];
    };
  };

  home.packages = with pkgs; [
    monaspace
    nerd-fonts.monaspace
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
  ];
}
