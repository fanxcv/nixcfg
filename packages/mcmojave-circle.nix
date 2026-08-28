# McMojave-circle 图标主题（vinceliuice，macOS Big Sur 风格圆形图标）
# GitHub archive tarball 动态生成（mtime 不稳定，fetchzip narHash 跨机不一致）→ vendor 到 assets/kde-sources/
# 仓库 src/ 目录即主题根（index.theme 在 src/ 下），装到 share/icons/McMojave-circle/
{ lib, stdenv }:
stdenv.mkDerivation {
  pname = "mcmojave-circle-icon-theme";
  version = "2025-08-07";

  src = ../assets/kde-sources/mcmojave-circle-2025-08-07.tar.gz;

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    tar -xzf "$src"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons
    cp -r McMojave-circle-2025-08-07/src "$out/share/icons/McMojave-circle"
    runHook postInstall
  '';

  meta = {
    description = "McMojave-circle icon theme (macOS Big Sur style)";
    homepage = "https://github.com/vinceliuice/McMojave-circle";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.all;
  };
}
