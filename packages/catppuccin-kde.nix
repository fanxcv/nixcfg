# Catppuccin KDE 主题（catppuccin/kde 官方仓库，Classic + Modern 两个 look-and-feel 变体 + 颜色方案）
# main 分支 tarball（无 release 资产）→ vendor 到 assets/kde-sources/
# generated/ 是仓库内构建产物：look-and-feel/{Classic,Modern}/Catppuccin-<Flavor>-<Accent>（4 flavor × 14 accent）
# 装全部（56×2 全局主题 + 56 颜色方案），KDE 里可随时切换；默认不启用（当前主主题 MacTahoe）
{ lib, stdenv }:
stdenv.mkDerivation {
  pname = "catppuccin-kde-theme";
  version = "main-2026-08-28";

  src = ../assets/kde-sources/catppuccin-kde-main.tar.gz;

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    tar -xzf "$src"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/plasma/look-and-feel $out/share/color-schemes
    cp -r kde-main/generated/look-and-feel/Classic "$out/share/plasma/look-and-feel/"
    cp -r kde-main/generated/look-and-feel/Modern "$out/share/plasma/look-and-feel/"
    cp -r kde-main/generated/color-schemes/. "$out/share/color-schemes/"
    runHook postInstall
  '';

  meta = {
    description = "Catppuccin KDE theme (Classic + Modern look-and-feel variants, all flavors/accents)";
    homepage = "https://github.com/catppuccin/kde";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
