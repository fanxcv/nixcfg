# 触摸板（按设备标识参数化）：本仓库所有笔记本共用，各自机器层只填自己的设备标识
# Plasma 6 的 libinput 触摸板 KCM 按设备写 kcminputrc 的 [Libinput][vendor][product][name] 段；
#   vendor / product 为**十进制**（十六进制值换算所得，见下），name 取 /proc/bus/input/devices 的 Name
# 通用 [Touchpad] 段只有自然滚动生效，ClickMethod 等按键行为必须落到设备专属段
#   （实测 nix-asus 真机 kcminputrc 通用段仅 NaturalScroll 被 Plasma 采纳）
# 用法（机器层，如 home/fan/nix-lenovo/plasma.touchpad.nix）：
#   imports = [ ../_nixos_/gui/desktop/plasma/touchpad.nix ];
#   softwares.touchpad = { vendorId = "04f3"; productId = "3293"; name = "ELAN06FA:00 04F3:3293 Touchpad"; };
# 已知设备：
#   nix-lenovo  ELAN06FA:00 04F3:3293 Touchpad   → 1267 / 12947
#   nix-asus    ASUE140D:00 04F3:31B9 Touchpad   → 1267 / 12729
{
  config,
  lib,
  ...
}:
let
  cfg = config.softwares.touchpad;
  # vendor / product 为十六进制字符串（同 /proc 的 Vendor=04f3 写法），此处转十进制组名
  toDecimal = hex: builtins.toString (lib.fromHexString hex);
in
{
  options.softwares.touchpad = {
    vendorId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "04f3";
      description = "触摸板 vendor ID（十六进制，取自 /proc/bus/input/devices 的 Vendor=）";
    };
    productId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "3293";
      description = "触摸板 product ID（十六进制，取自 /proc/bus/input/devices 的 Product=）";
    };
    name = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ELAN06FA:00 04F3:3293 Touchpad";
      description = "触摸板设备名（取自 /proc/bus/input/devices 的 Name=）";
    };
    # 自然滚动由共享的 plasma.mouse.nix 通用段覆盖（鼠标与触摸板同款），此处只补按键行为
    naturalScroll = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "自然滚动（与 macOS 方向一致）";
    };
    clickMethod = lib.mkOption {
      type = lib.types.enum [
        "bottomRight"
        "twoFingers"
      ];
      default = "twoFingers";
      description = "右键方式：bottomRight = 按右下角；twoFingers = 双指按下任意位置";
    };
  };

  config = lib.mkIf (cfg.vendorId != null && cfg.productId != null && cfg.name != null) {
    programs.plasma.configFile.kcminputrc = {
      "Libinput/${toDecimal cfg.vendorId}/${toDecimal cfg.productId}/${cfg.name}" = {
        NaturalScroll = cfg.naturalScroll;
        # 1 = button areas（右下角），2 = clickfinger（双指任意位置）
        ClickMethod = if cfg.clickMethod == "twoFingers" then 2 else 1;
      };
    };
  };
}
