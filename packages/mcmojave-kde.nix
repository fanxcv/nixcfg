# McMojave KDE 主题（vinceliuice，macOS 风格全套：aurorae 窗口装饰[红绿灯+毛玻璃] + 颜色方案 + Plasma 样式 + 全局主题）
# GitHub tarball（无 release 资产）；只装 aurorae/color-schemes/plasma 三部分（Kvantum/sddm/wallpaper 不用）
# aurorae 装饰装到 share/aurorae/themes/McMojave/，kwinrc 里 org.kde.kdecoration2 的 theme=McMojave 启用
{ lib, stdenv, fetchzip }:
stdenv.mkDerivation {
  pname = "mcmojave-kde-theme";
  version = "2024-10-20";

  src = fetchzip {
    url = "https://github.com/vinceliuice/McMojave-kde/archive/refs/tags/2024-10-20.tar.gz";
    hash = "sha256-4INopkfRe2g+FJRUW1DDVEP79O9TuLo3W5BSAmMTXSc=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/aurorae/themes $out/share/color-schemes $out/share/plasma
    cp -r "$src/aurorae/McMojave" "$out/share/aurorae/themes/"
    cp -r "$src/color-schemes/." "$out/share/color-schemes/"
    cp -r "$src/plasma/desktoptheme" "$out/share/plasma/"
    cp -r "$src/plasma/look-and-feel" "$out/share/plasma/"
    runHook postInstall
  '';

  meta = {
    description = "McMojave KDE theme (macOS style: aurorae window decoration with traffic-light buttons + frosted glass)";
    homepage = "https://github.com/vinceliuice/McMojave-kde";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.all;
  };
}
