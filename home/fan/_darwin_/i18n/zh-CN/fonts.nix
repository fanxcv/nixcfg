# fontconfig 默认字体（用户层）：中文苹方 + 等宽 Monaspace Nerd Font
_: {
  fonts.fontconfig = {
    enable = true;
    antialiasing = true;
    hinting = "full";
    subpixelRendering = "rgb";
    defaultFonts = {
      serif = [
        "PingFang SC"
      ];
      sansSerif = [
        "PingFang SC"
      ];
      monospace = [
        "MonaspiceNe Nerd Font Mono"
      ];
      emoji = [
        "Apple Color Emoji"
      ];
    };
  };
}
