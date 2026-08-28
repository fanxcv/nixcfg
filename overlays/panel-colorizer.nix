# plasma-panel-colorizer 修复 overlay：nixpkgs 打包缺两处运行时依赖
# 1) contents/ui/tools/*.sh 未保留可执行位（nix store 只读，插件调 list_presets.sh 报"权限不够"）
# 2) 插件运行时调 python3（service.py），plasmashell 的 PATH 无 python3 → 需 home.packages 加 python3（见 plasma.theme.nix）
{ }:
final: prev: {
  plasma-panel-colorizer = prev.plasma-panel-colorizer.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      chmod +x $out/share/plasma/plasmoids/luisbocanegra.panel.colorizer/contents/ui/tools/*.sh
    '';
  });
}
