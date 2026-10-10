# 鼠标/触控板：自然滚动（tsln 同款）
let
  # 对齐 macOS/Linux 的触控板和鼠标方向
  NaturalScroll = true;
in
{
  programs.plasma.configFile = {
    kcminputrc = {
      "Touchpad" = {
        inherit NaturalScroll;
      };

      "Mouse" = {
        inherit NaturalScroll;
      };

      # 0x046D:0xC548 Logi Bolt Receiver
      "Libinput/1133/50504/Logitech USB Receiver Mouse" = {
        inherit NaturalScroll;
      };
    };
  };
}
