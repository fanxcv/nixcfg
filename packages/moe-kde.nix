# Moe KDE 主题全套（GitLab jomada/moe-theme，按帖子用到 颜色/Plasma 样式/look-and-feel）
# 资源：color-schemes/Moe.colors、plasma/Moe（Plasma 5 系 desktoptheme，KDE6 兼容降级）、look-and-feel/Moe（全局主题）
# 安装路径对应 plasma-manager：lookAndFeel="Moe"、desktopTheme="Moe"、colorScheme="Moe"
{ lib, stdenv, fetchgit }:
stdenv.mkDerivation {
  pname = "moe-kde-theme";
  version = "2.6";

  src = fetchgit {
    url = "https://gitlab.com/jomada/moe-theme.git";
    rev = "9348ce4360b39531690d91cf61fae948890ea99d";
    sha256 = "sha256-FsgSrkF3eB6mcu5XM4cMCMlFtZZ5GomOmkKILSDT2+w=";
  };

  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/color-schemes $out/share/plasma/desktoptheme $out/share/plasma/look-and-feel
    cp $src/color-schemes/Moe.colors $out/share/color-schemes/
    cp -r $src/plasma/Moe $out/share/plasma/desktoptheme/
    cp -r $src/look-and-feel/Moe $out/share/plasma/look-and-feel/
    runHook postInstall
  '';

  meta = {
    description = "Moe KDE theme (color-scheme + plasma style + look-and-feel)";
    homepage = "https://gitlab.com/jomada/moe-theme";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
  };
}
