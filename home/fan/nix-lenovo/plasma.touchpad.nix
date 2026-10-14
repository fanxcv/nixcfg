# 触摸板（ELAN06FA:00 04F3:3293，ThinkBook 14 G6+ AHP）：自然滚动 + 双指按下任意位置为右键
# 实现与已知设备见 ../_nixos_/gui/desktop/plasma/touchpad.nix
{ ... }:
{
  imports = [ ../_nixos_/gui/desktop/plasma/touchpad.nix ];

  softwares.touchpad = {
    vendorId = "04f3";
    productId = "3293";
    name = "ELAN06FA:00 04F3:3293 Touchpad";
  };
}
