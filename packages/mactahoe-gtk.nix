# MacTahoe GTK 主题（vinceliuice，macOS Tahoe 风格 GTK2/3/4 + xfwm4 + metacity + plank）
# 用 release 预构建 tar.xz（MacTahoe-Dark.tar.xz 解包顶层即主题目录）→ 装到 share/themes/
# 供 KDE 的 GTK 应用（Firefox/Thunderbird 等）用；gtk.theme 配置见 plasma.theme.nix
{ lib, stdenv }:
stdenv.mkDerivation {
  pname = "mactahoe-gtk-theme";
  version = "2026-08-08";

  src = ../assets/kde-sources/mactahoe-gtk-2026-08-08.tar.gz;

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    tar -xzf "$src"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/themes
    tar -xJf MacTahoe-gtk-theme-2026-08-08/release/MacTahoe-Dark.tar.xz -C $out/share/themes
    tar -xJf MacTahoe-gtk-theme-2026-08-08/release/MacTahoe-Light.tar.xz -C $out/share/themes
    runHook postInstall
  '';

  meta = {
    description = "MacTahoe GTK theme (macOS Tahoe style for GTK desktops)";
    homepage = "https://github.com/vinceliuice/MacTahoe-gtk-theme";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.all;
  };
}
