# 触摸板（ASUE140D:00 04F3:31B9，ASUS Zenbook UM5302TA）：自然滚动 + 双指按下任意位置为右键
# 实现与已知设备见 ../_nixos_/gui/desktop/plasma/touchpad.nix
# 设备标识取自真机 /proc/bus/input/devices：Vendor=04f3 Product=31b9
{ ... }:
{
  imports = [ ../_nixos_/gui/desktop/plasma/touchpad.nix ];

  softwares.touchpad = {
    vendorId = "04f3";
    productId = "31b9";
    name = "ASUE140D:00 04F3:31B9 Touchpad";
  };
}
