# KasmVNC 官方 deb 解包（nixpkgs 无此包；kasmweb 是完整 Workspaces 发行版，太重且 unfree）
# 用途：容器/无 GPU 机器浏览器远程桌面（Xvnc + 内置 web 客户端，http://<host>:6901/vnc.html）
# 版本升级：改 version + 下载后重算 sha256（shasum -a 256；deb 的 data.tar 是 zst，见 unpackPhase）
# 网络：官方 release 直连国内不稳，主 URL 用 ghfast.top 镜像，官方作备用（fetchurl 按序尝试）
#
# 结构：usr/bin/{Xkasmvnc,kasmvncserver(perl),kasmvncconfig(ELF),kasmvncpasswd(ELF),kasmxproxy} +
#   usr/share/kasmvnc/{www(web 客户端),kasmvnc_defaults.yaml} + usr/share/perl5/KasmVNC/*.pm + usr/lib/kasmvncserver/select-de.sh
# 坑位：
#   - kasmvncserver 硬编码 /usr/share/kasmvnc/kasmvnc_defaults.yaml 与 /usr/lib/kasmvncserver/select-de.sh → sed 指 store
#   - perl 模块（KasmVNC 自带 + perlPackages 外部依赖）→ wrapProgram PERL5LIB
#   - Xvnc 运行时需 xkb 数据（XKB_BASE）+ xkbcomp/xauth 命令 → wrapProgram 注入
#   - 字体：x_font_path 默认 auto 找不到 nix 字体，用户配置里显式指 dejavu_fonts
#   - libxcrypt 4.x soname 已升 libcrypt.so.2（26.05），deb 二进制要 libcrypt.so.1 →
#     postFixup 里 patchelf --replace-needed + 补 RPATH（crypt 符号 XCRYPT_2.0 节点未变，ABI 兼容）
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  perl,
  perlPackages,
  libpng,
  zlib,
  libunwind,
  pixman,
  libXfont2,
  libXau,
  libXdmcp,
  libxshmfence,
  libX11,
  libXext,
  libXtst,
  libXrandr,
  libXcursor,
  libXfixes,
  systemdLibs,
  libGL,
  mesa,
  openssl,
  libxcrypt,
  freetype,
  dejavu_fonts,
  xauth,
  xkbcomp,
  xkeyboard_config,
}:
let
  version = "1.5.0";
in
stdenv.mkDerivation {
  pname = "kasmvnc";
  inherit version;

  src = fetchurl {
    urls = [
      "https://ghfast.top/https://github.com/kasmtech/KasmVNC/releases/download/v${version}/kasmvncserver_noble_${version}_amd64.deb"
      "https://github.com/kasmtech/KasmVNC/releases/download/v${version}/kasmvncserver_noble_${version}_amd64.deb"
    ];
    sha256 = "f599fe02e2175b9817b6165f74a5d2bebdc73118dde9181ba3410963bed7ae1e";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook makeWrapper ];

  # Xkasmvnc 的 DT_NEEDED 全链（ldd 核对）：libpng/libz/libunwind/libpixman/libXfont2/libXau/
  #   libsystemd/libxshmfence/libXdmcp/libGL/libgbm/libssl/libcrypto/libcrypt/libfreetype/libstdc++
  #   kasmxproxy 另需 libX11/libXext/libXtst/libXrandr/libXcursor/libXfixes；kasmvncconfig 需 libX11
  buildInputs = [
    libpng
    zlib
    libunwind
    pixman
    libXfont2
    libXau
    libXdmcp
    libxshmfence
    libX11
    libXext
    libXtst
    libXrandr
    libXcursor
    libXfixes
    systemdLibs
    libGL
    mesa
    openssl
    libxcrypt
    freetype
  ];

  unpackPhase = ''
    dpkg-deb -x "$src" .
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r usr/bin usr/share usr/lib $out/
    runHook postInstall
  '';

  postFixup = ''
    # perl 脚本 shebang → nix perl（kasmvncserver；select-de.sh 是 bash）
    patchShebangs $out
    # 硬编码路径 → store（kasmvncserver 读 defaults yaml、调 select-de.sh）
    substituteInPlace $out/bin/kasmvncserver \
      --replace "/usr/share/kasmvnc/kasmvnc_defaults.yaml" "$out/share/kasmvnc/kasmvnc_defaults.yaml" \
      --replace "/usr/lib/kasmvncserver/select-de.sh" "$out/lib/kasmvncserver/select-de.sh"
    # defaults yaml 的 httpd_directory 写死 /usr/share/kasmvnc/www → 指 store
    substituteInPlace $out/share/kasmvnc/kasmvnc_defaults.yaml \
      --replace "/usr/share/kasmvnc/www" "$out/share/kasmvnc/www"
    # libxcrypt 4.x 只出 libcrypt.so.2，deb 二进制（Xkasmvnc/kasmvncpasswd）要 libcrypt.so.1
    # → replace-needed 指 libcrypt.so.2 + 补 RPATH（autoPatchelfHook 只加匹配到的依赖目录）
    patchelf --replace-needed libcrypt.so.1 libcrypt.so.2 \
      --add-rpath ${libxcrypt}/lib \
      $out/bin/Xkasmvnc $out/bin/kasmvncpasswd
    # perl 模块（自带 + perlPackages 外部依赖）+ 运行时命令（xkbcomp/xauth）+ xkb 数据
    wrapProgram $out/bin/kasmvncserver \
      --prefix PERL5LIB : "$out/share/perl5" \
      --prefix PERL5LIB : "${perl.withPackages (pp: [
        pp.Switch pp.YAMLTiny pp.HashMergeSimple pp.ScalarListUtils pp.ListMoreUtils
        pp.TryTiny pp.DateTime pp.DateTimeTimeZone
      ])}/lib/perl5/site_perl" \
      --prefix PATH : "${xkbcomp}/bin:${xauth}/bin" \
      --set XKB_BASE "${xkeyboard_config}/share/X11/xkb"
  '';

  meta = {
    description = "KasmVNC: web-based remote desktop (Xvnc + built-in browser client)";
    homepage = "https://github.com/kasmtech/KasmVNC";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
