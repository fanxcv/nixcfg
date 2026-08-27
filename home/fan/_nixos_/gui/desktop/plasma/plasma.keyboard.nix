# 键盘：Plasma 会话启动开 NumLock（tsln 同款；SDDM 层 autoNumlock 在 hosts/_nixos_/gui/desktop/plasma.nix）
{
  programs.plasma.input.keyboard.numlockOnStartup = "on";
}
