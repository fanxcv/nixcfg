# 开机画面：Plymouth breeze 主题 + 静默内核输出（tsln 同款；主题由 themes/catppuccin.nix 的
# catppuccin.plymouth.enable 套 Catppuccin 皮肤）
{ lib, ... }:
{
  boot = {
    plymouth = {
      enable = true;
      theme = lib.mkDefault "breeze";
    };

    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };
}
