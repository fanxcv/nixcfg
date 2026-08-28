# McMojave KDE 主题（vinceliuice，macOS 风格全套：aurorae 窗口装饰[红绿灯+毛玻璃] + 颜色方案 + Plasma 样式 + 全局主题）
# GitHub archive tarball 动态生成（mtime 不稳定，fetchzip narHash 跨机不一致）→ vendor 到 assets/kde-sources/
# 只装 aurorae/color-schemes/plasma 三部分（Kvantum/sddm/wallpaper 不用）
# aurorae 装饰装到 share/aurorae/themes/McMojave/，kwinrc 里 org.kde.kdecoration2 的 theme=McMojave 启用
{ lib, stdenv }:
stdenv.mkDerivation {
  pname = "mcmojave-kde-theme";
  version = "2024-10-20";

  src = ../assets/kde-sources/mcmojave-kde-2024-10-20.tar.gz;

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    tar -xzf "$src"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/aurorae/themes $out/share/color-schemes $out/share/plasma
    cp -r McMojave-kde-2024-10-20/aurorae/McMojave "$out/share/aurorae/themes/"
    cp -r McMojave-kde-2024-10-20/color-schemes/. "$out/share/color-schemes/"
    cp -r McMojave-kde-2024-10-20/plasma/desktoptheme "$out/share/plasma/"
    cp -r McMojave-kde-2024-10-20/plasma/look-and-feel "$out/share/plasma/"
    runHook postInstall
  '';

  meta = {
    description = "McMojave KDE theme (macOS style: aurorae window decoration with traffic-light buttons + frosted glass)";
    homepage = "https://github.com/vinceliuice/McMojave-kde";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.all;
  };
}
