# Hoshino Swimsuit X11 光标主题（KDE 商店，已 vendor 到 assets/kde-sources/）
# zip 内顶层目录 Takanashi-Hoshino-Swimsuit/{cursors/,index.theme}，装到 share/icons/<theme>/
# 主题目录名沿用 zip 内目录名；KDE 经 index.theme 的 Name 显示 " Hoshino Swimsuit"
{ lib, stdenv, unzip }:
stdenv.mkDerivation {
  pname = "hoshino-swimsuit-cursor";
  version = "1.0";

  src = ../assets/kde-sources/hoshino-swimsuit.zip;

  nativeBuildInputs = [ unzip ];
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons
    unzip -q "$src" -d "$out/share/icons"
    runHook postInstall
  '';

  meta = {
    description = "Hoshino Swimsuit X11 cursor theme (Blue Archive)";
    homepage = "https://store.kde.org/p/2157792";
    license = lib.licenses.cc0;
    platforms = lib.platforms.all;
  };
}
