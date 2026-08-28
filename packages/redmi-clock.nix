# Redmi Clock plasmoid（KDE 商店，已 vendor 到 assets/kde-sources/，JWT 链接会过期不能 fetchurl）
# 文件是 xz 压缩的 tar，顶层目录 Redmi.Clock/，装到 share/plasma/plasmoids/
{ lib, stdenv, xz, gnutar }:
stdenv.mkDerivation {
  pname = "redmi-clock";
  version = "0.6.8";

  src = ../assets/kde-sources/redmi-clock-0.6.8.plasmoid;

  nativeBuildInputs = [ xz gnutar ];
  dontBuild = true;
  dontConfigure = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/plasma/plasmoids
    xz -dc "$src" | tar -x -C $out/share/plasma/plasmoids
    runHook postInstall
  '';

  meta = {
    description = "Redmi Clock KDE plasmoid (desktop clock widget)";
    homepage = "https://store.kde.org/p/2175475";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
  };
}
