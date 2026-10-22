# 触摸板（PNP0C50:00 093A:0255，无界14S）：自然滚动 + 双指按下任意位置为右键
# 实现与已知设备见 ../_nixos_/gui/desktop/plasma/touchpad.nix
{ ... }:
{
  imports = [ ../_nixos_/gui/desktop/plasma/touchpad.nix ];

  softwares.touchpad = {
    vendorId = "093a";
    productId = "0255";
    name = "PNP0C50:00 093A:0255 Touchpad";
  };
}
