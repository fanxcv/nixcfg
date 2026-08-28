# Fedora 全局主题（org.fedoraproject.fedora.desktop look-and-feel），从 Fedora koji rpm 提取
# rpm payload 是 zstd（rpm2cpio 输出 cpio 流，bsdtar 解包），取 usr/share/plasma/look-and-feel/<主题> 装到 $out
{ lib, stdenv, fetchurl, rpm, libarchive }:
stdenv.mkDerivation {
  pname = "fedora-look-and-feel";
  version = "6.7.4";

  src = fetchurl {
    url = "https://kojipkgs.fedoraproject.org/packages/plasma-workspace/6.7.4/1.fc45/noarch/plasma-lookandfeel-fedora-6.7.4-1.fc45.noarch.rpm";
    sha256 = "sha256-vlgAhFlvXDR6UvVJFwoyuBVLG8aqZjRd4fBS2Fb8a3w=";
  };

  nativeBuildInputs = [ rpm libarchive ];
  dontBuild = true;
  dontConfigure = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    cd "$TMPDIR"
    rpm2cpio "$src" | bsdtar -x -f -
    mkdir -p $out/share/plasma/look-and-feel
    # rpm 内主题目录：usr/share/plasma/look-and-feel/org.fedoraproject.fedora.desktop
    cp -r usr/share/plasma/look-and-feel/org.fedoraproject.fedora.desktop $out/share/plasma/look-and-feel/
    runHook postInstall
  '';

  meta = {
    description = "Fedora Plasma global look-and-feel theme (org.fedoraproject.fedora.desktop)";
    homepage = "https://fedoraproject.org/";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.all;
  };
}
