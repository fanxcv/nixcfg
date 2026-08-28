# MacTahoe KDE 主题（vinceliuice，macOS Tahoe 风格：aurorae 窗口装饰[红绿灯+圆角] + 颜色方案 + Plasma 样式 + 全局主题）
# main 分支 tarball（无 tag/release 资产）→ vendor 到 assets/kde-sources/
# 只装 aurorae/color-schemes/plasma 三部分（Kvantum/sddm/wallpapers 不用）
# 全局主题名 com.github.vinceliuice.MacTahoe-Dark/-Light；装饰名 MacTahoe-Dark/-Light
{ lib, stdenv }:
stdenv.mkDerivation {
  pname = "mactahoe-kde-theme";
  version = "main-2026-08-28";

  src = ../assets/kde-sources/mactahoe-kde-main.tar.gz;

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    tar -xzf "$src"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/aurorae/themes $out/share/color-schemes $out/share/plasma
    # aurorae 主题：svg + <color>rc + icons<color> svg + metadata（install.sh 同款，sed 替换 theme_name）
    for pair in "MacTahoe-Dark:Darkrc:icons-Dark" "MacTahoe-Light:Lightrc:icons-Light"; do
      IFS=: read -r theme rc icons <<< "$pair"
      mkdir -p "$out/share/aurorae/themes/$theme"
      cp -r "MacTahoe-kde-main/aurorae/$theme/." "$out/share/aurorae/themes/$theme/"
      cp "MacTahoe-kde-main/aurorae/$rc" "$out/share/aurorae/themes/$theme/$theme"rc
      cp MacTahoe-kde-main/aurorae/$icons/*.svg "$out/share/aurorae/themes/$theme/"
      cp MacTahoe-kde-main/aurorae/metadata.desktop MacTahoe-kde-main/aurorae/metadata.json "$out/share/aurorae/themes/$theme/"
      sed -i "s/theme_name/$theme/g" "$out/share/aurorae/themes/$theme/metadata.desktop" "$out/share/aurorae/themes/$theme/metadata.json"
    done
    cp -r MacTahoe-kde-main/color-schemes/. "$out/share/color-schemes/"
    cp -r MacTahoe-kde-main/plasma/desktoptheme "$out/share/plasma/"
    cp -r MacTahoe-kde-main/plasma/look-and-feel "$out/share/plasma/"
    runHook postInstall
  '';

  meta = {
    description = "MacTahoe KDE theme (macOS Tahoe style: aurorae window decoration with traffic-light buttons + rounded corners)";
    homepage = "https://github.com/vinceliuice/MacTahoe-kde";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.all;
  };
}
