# fontconfig 默认字体（用户层）：中文苹方（Monaspace 已移除，等宽字体不指定用系统默认）
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
      emoji = [
        "Apple Color Emoji"
      ];
    };
  };
}
