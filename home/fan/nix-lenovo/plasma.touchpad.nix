# 触摸板（ELAN06FA:00 04F3:3293，ThinkBook 14 G6+ AHP）：自然滚动 + 双指按下任意位置为右键
# Plasma 6 的 libinput 触摸板 KCM 按设备写 kcminputrc 的 [Libinput][vendor][product][name] 段
# （组名取自本机 GUI 写出的实际配置，设备改名/换机需同步；通用 [Touchpad] 段兜底见
#  home/fan/_nixos_/gui/desktop/plasma/plasma.mouse.nix）
# ClickMethod：1 = 按右下角（button areas），2 = 双指按下任意位置（clickfinger）
{
  programs.plasma.configFile.kcminputrc = {
    "Libinput/1267/12947/ELAN06FA:00 04F3:3293 Touchpad" = {
      NaturalScroll = true;
      ClickMethod = 2;
    };
  };
}
