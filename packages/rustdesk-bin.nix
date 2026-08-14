# RustDesk 官方 GitHub Release 二进制（.deb 解包，免本地编译）
# 背景：nixpkgs 的 rustdesk 是源码编译（rust 大项目 + libsciter，虚拟机 ~1h 且无 cache 缓存）；
#   官方 release 是 Flutter 预编译版（librustdesk.so 47MB 自包含），下载解包即用
# 版本升级：改 version + 下载后重算 sha256（shasum -a 256；deb 的 data.tar 是 xz，见 unpackPhase）
# 网络：官方 release 直连国内不稳，主 URL 用 ghfast.top 镜像，官方作备用（fetchurl 按序尝试）
# 依赖：autoPatchelfHook 按 NEEDED 自动补 nix store 路径；同目录 so 互依赖用 postFixup 补 $out/lib
{ lib, stdenv, fetchurl, autoPatchelfHook, xz
, gtk3, glib, libxcb, xorg, libxkbcommon, wayland, dbus
, gst_all_1, pam, pulseaudio, libva, zlib, fontconfig, libepoxy
, alsa-lib, systemdLibs, curl, xdotool, libnsl
}:
stdenv.mkDerivation {
  pname = "rustdesk-bin";
  version = "1.4.9";

  src = fetchurl {
    urls = [
      "https://ghfast.top/https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.deb"
      "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.deb"
    ];
    sha256 = "sha256-ckS6R8QOgEFyBEv75llGfFTORlVMmOeMjAQG8dYS/aM=";
  };

  # deb 的 Depends 映射（librustdesk.so 的 NEEDED：gtk3 全家/gstreamer/pulse/vaapi/xcb/pam/dbus/xkb）
  nativeBuildInputs = [ autoPatchelfHook xz ];
  buildInputs = [
    gtk3 glib libxcb xorg.libX11 xorg.libXfixes xorg.libXtst libxkbcommon wayland
    dbus gst_all_1.gstreamer gst_all_1.gst-plugins-base pam pulseaudio libva zlib
    fontconfig libepoxy alsa-lib systemdLibs curl xdotool libnsl
    stdenv.cc.cc.lib # libstdc++/libgcc_s（Flutter/rust 二进制必需）
  ];

  unpackPhase = ''
    ar x "$src"
    tar -xf data.tar.xz
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/rustdesk $out/bin $out/share/applications $out/share/icons
    cp -r usr/share/rustdesk/* $out/share/rustdesk/
    cp -r usr/share/icons/hicolor $out/share/icons/
    # launcher 在 share/rustdesk/ 下，$ORIGIN 定位同目录 lib/（真实文件路径，symlink 不影响）
    ln -s ../share/rustdesk/rustdesk $out/bin/rustdesk
    cp usr/share/applications/*.desktop $out/share/applications/
    runHook postInstall
  '';

  # autoPatchelf 已重写 interpreter + buildInputs 的 RUNPATH；补同目录库（libapp.so → librustdesk.so 等）
  postFixup = ''
    find $out/share/rustdesk -type f \( -name 'rustdesk' -o -name '*.so' \) \
      -exec patchelf --add-rpath '${placeholder "out"}/share/rustdesk/lib' {} \;
  '';

  dontStrip = true;

  meta = {
    description = "Remote desktop client (official binary release, no local build)";
    homepage = "https://rustdesk.com";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
