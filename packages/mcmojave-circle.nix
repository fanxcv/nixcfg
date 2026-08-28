# McMojave-circle 图标主题（vinceliuice，macOS Big Sur 风格圆形图标）
# GitHub tarball（无 release 资产，用 archive/refs/tags）；仓库 src/ 目录即主题根（index.theme 在 src/ 下）
# 装到 share/icons/McMojave-circle/（目录名 = 主题名，KDE 经 index.theme 的 Name 显示 "McMojave-circle"）
{ lib, stdenv, fetchzip }:
stdenv.mkDerivation {
  pname = "mcmojave-circle-icon-theme";
  version = "2025-08-07";

  src = fetchzip {
    url = "https://github.com/vinceliuice/McMojave-circle/archive/refs/tags/2025-08-07.tar.gz";
    hash = "sha256-4s6XKcgHVM+paNCRI2rPthEcr9VImxmXdYLGLZbku4Q=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons
    cp -r "$src/src" "$out/share/icons/McMojave-circle"
    runHook postInstall
  '';

  meta = {
    description = "McMojave-circle icon theme (macOS Big Sur style)";
    homepage = "https://github.com/vinceliuice/McMojave-circle";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.all;
  };
}
