# RustDesk 官方 GitHub Release 二进制（.deb 解包，免本地编译）
# 背景：nixpkgs 的 rustdesk 是源码编译（rust 大项目 + libsciter，虚拟机 ~1h 且无 cache 缓存）；
#   官方 release 是 Flutter 预编译版（librustdesk.so 47MB 自包含），下载解包即用
# 版本升级：改 version + 下载后重算 sha256（shasum -a 256；deb 的 data.tar 是 xz，见 unpackPhase）
# 网络：官方 release 直连国内不稳，主 URL 用 ghfast.top 镜像，官方作备用（fetchurl 按序尝试）
#
# ⚠ 2026-08 大坑（勿回退）：对 Flutter 二进制跑 autoPatchelf/patchelf 会重写 ELF 段，
#   破坏 Dart AOT snapshot 定位，启动即崩（FATAL: Invalid vm isolate snapshot）。
#   现方案：deb 原样解包（原始 RUNPATH=$ORIGIN/lib 自足）+ buildFHS 环境提供系统库，
#   ELF 零改动。已验证：virtio-gl VM（renderD128）+ Wayland 会话正常启动。
{ lib, stdenv, fetchurl, xz, buildFHSEnv
, gtk3, glib, libxcb, xorg, libxkbcommon, wayland, dbus
, gst_all_1, pam, pulseaudio, libva, zlib, fontconfig, libepoxy
, alsa-lib, systemdLibs, curl, xdotool, libnsl
}:
let
  src = fetchurl {
    urls = [
      "https://ghfast.top/https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.deb"
      "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.deb"
    ];
    sha256 = "sha256-ckS6R8QOgEFyBEv75llGfFTORlVMmOeMjAQG8dYS/aM=";
  };

  # 原样解包：ELF 文件一律不动（原始 RUNPATH=$ORIGIN/lib 定位同目录 lib/）
  raw = stdenv.mkDerivation {
    pname = "rustdesk-raw";
    version = "1.4.9";
    inherit src;
    nativeBuildInputs = [ xz ];
    dontStrip = true;
    dontAutoPatchelf = true;
    unpackPhase = ''
      ar x "$src"
      tar -xf data.tar.xz
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/rustdesk $out/bin $out/share/icons $out/share/applications
      cp -r usr/share/rustdesk/* $out/share/rustdesk/
      cp -r usr/share/icons/hicolor $out/share/icons/
      cp usr/share/applications/*.desktop $out/share/applications/
      # launcher 在 share/rustdesk/ 下，$ORIGIN 定位同目录 lib/（真实文件路径，symlink 不影响）
      ln -s ../share/rustdesk/rustdesk $out/bin/rustdesk
      runHook postInstall
    '';
  };

  # FHS 环境：NixOS 无 /usr/lib，提供系统库 + raw 的 deb 解释器（/lib64/ld-linux-x86-64.so.2）
  fhs = buildFHSEnv {
    name = "rustdesk-bin";
    runScript = "rustdesk";
    targetPkgs = pkgs: [
      raw
      gtk3 glib libxcb xorg.libX11 xorg.libXfixes xorg.libXtst libxkbcommon wayland
      dbus gst_all_1.gstreamer gst_all_1.gst-plugins-base pam pulseaudio libva zlib
      fontconfig libepoxy alsa-lib systemdLibs curl xdotool libnsl
      stdenv.cc.cc.lib # libstdc++/libgcc_s（Flutter/rust 二进制必需）
    ];
  };
in
stdenv.mkDerivation {
  pname = "rustdesk-bin";
  version = "1.4.9";

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/applications $out/share/icons
    cp ${fhs}/bin/rustdesk-bin $out/bin/rustdesk
    cp -r ${raw}/share/icons/* $out/share/icons/
    cp ${raw}/share/applications/*.desktop $out/share/applications/
    substituteInPlace $out/share/applications/*.desktop \
      --replace-fail "/usr/bin/rustdesk" "$out/bin/rustdesk"
    runHook postInstall
  '';

  meta = {
    description = "Remote desktop client (official binary release via FHS, no patchelf)";
    homepage = "https://rustdesk.com";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
