# Catppuccin NixOS 用户级主题开关（tsln 同款）：桌面 + 输入法皮肤 + 壁纸 + Konsole
{ lib, ... }:
{
  catppuccin = {
    plasma.enable = lib.mkDefault true;
    fcitx5.enable = lib.mkDefault true;
    wallpaper.enable = lib.mkDefault true;

    konsole.enable = lib.mkDefault true;
    konsole.flavor = lib.mkDefault "mocha";
  };

  # 防复发：plasma-manager 主题应用脚本（apply_themes）靠 last_run 文件防重跑（sha256 对比，
  # 内容不变即跳过）；Plasma 运行时写回 ~/.config/kdeglobals 会丢 ColorScheme 回到 Breeze 默认，
  # 此后脚本永不重跑。每次部署删 last_run，强制下次登录重应用主题（rm -f 幂等，无害）
  home.activation.forcePlasmaThemeReapply = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "$HOME/.local/share/plasma-manager/last_run_script_apply_themes"
  '';
}
