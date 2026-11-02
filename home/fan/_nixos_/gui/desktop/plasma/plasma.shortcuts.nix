# 截图快捷键的声明式覆盖（组件本体见 hosts/_nixos_/gui/desktop/plasma.nix 的
# share/kglobalaccel/spectacle-region.desktop）。
# Ctrl+Alt+A 沿用微信截图的老习惯；微信侧的占用已由用户释放，此处不再有冲突。
_:
{
  programs.plasma.shortcuts."spectacle-region.desktop"."spectacle-region" = [ "Ctrl+Alt+A" ];

  # 与真实组件（wechat/qq 等）一致带上 _k_friendly_name：会话启动加载快捷键组件时靠它识别
  programs.plasma.configFile."kglobalshortcutsrc"."spectacle-region.desktop"."_k_friendly_name" = "Screenshot";
}
