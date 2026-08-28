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
#   - libxcrypt 4.x soname 由 hashes 组决定：strong（无 descrypt）→ obsolete-api 强制 no → libcrypt.so.2；
#     glibc 组（含 descrypt）→ obsolete-api 保留 → libcrypt.so.1，与 deb 二进制 NEEDED 直接匹配，无需 patchelf
#   - nixpkgs libxcrypt 默认 --enable-hashes=strong 不含 sha256crypt（$5$），KasmVNC 用 $5$kasm$ 盐
#     → crypt() 返回 NULL → kasmvncpasswd 段错误；override enableHashes=glibc（descrypt/md5/sha256/sha512）
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
  coreutils,
  hostname,
  util-linux,
  xdpyinfo,
}:
let
  version = "1.5.0";
  # nixpkgs 默认 --enable-hashes=strong 只含 [y gy sm3y 7 2b 2y 2a 6]，无 sha256crypt（$5$）
  # KasmVNC 密码哈希用 $5$kasm$ 盐 → crypt() 返回 NULL → kasmvncpasswd 段错误
  # glibc 组 = descrypt/md5crypt/sha256crypt/sha512crypt（传统 libcrypt 全集），
  # 且含 descrypt → obsolete-api 保留 → soname libcrypt.so.1，与 deb 二进制 NEEDED 匹配
  libxcryptCompat = libxcrypt.override { enableHashes = "glibc"; };
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
    perl # patchShebangs 靠 type -P perl 找解释器，perl 不在 buildInputs 则 shebang 保持 /usr/bin/perl（系统 5.38）
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
    libxcryptCompat
    freetype
  ];

  unpackPhase = ''
    dpkg-deb -x "$src" .
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r usr/bin usr/share usr/lib etc $out/
    runHook postInstall
  '';

  postFixup = ''
    # deb postinst 用 update-alternatives 建 generic 名 symlink（去 kasm 前缀），解包无此 symlink：
    #   Xvnc→Xkasmvnc、vncpasswd→kasmvncpasswd（kasmvncserver 第 504 行检查这两个）；
    #   vncserver/vncconfig/xproxy 内部不用，一并建上保完整
    ln -s Xkasmvnc $out/bin/Xvnc
    ln -s kasmvncpasswd $out/bin/vncpasswd
    ln -s kasmvncserver $out/bin/vncserver
    ln -s kasmvncconfig $out/bin/vncconfig
    ln -s kasmxproxy $out/bin/xproxy
    # perl 脚本 shebang → nix perl（kasmvncserver；select-de.sh 是 bash）
    patchShebangs $out
    # 硬编码路径 → store（kasmvncserver 读 defaults yaml、调 select-de.sh、读系统配置目录）
    substituteInPlace $out/bin/kasmvncserver \
      --replace "/usr/share/kasmvnc/kasmvnc_defaults.yaml" "$out/share/kasmvnc/kasmvnc_defaults.yaml" \
      --replace "/usr/lib/kasmvncserver/select-de.sh" "$out/lib/kasmvncserver/select-de.sh" \
      --replace "/etc/kasmvnc" "$out/etc/kasmvnc"
    # defaults yaml 的 httpd_directory 写死 /usr/share/kasmvnc/www → 指 store
    substituteInPlace $out/share/kasmvnc/kasmvnc_defaults.yaml \
      --replace "/usr/share/kasmvnc/www" "$out/share/kasmvnc/www"
    # 注：auto-patchelf 注册在 postFixupHooks（postFixup 之后跑），此处勿再改 NEEDED——
    # glibc 组 libxcrypt soname 即 libcrypt.so.1，与 deb 二进制原始 NEEDED 匹配，auto-patchelf 自会找到
    # perl 模块（自带 + perlPackages 外部依赖）+ 运行时命令（xkbcomp/xauth）+ xkb 数据
    # 坑：perlPackages 模块装在 site_perl/<perl.version>/ 子目录，PERL5LIB 不自动追加版本目录
    #   （只有编译期 @INC 才追加），必须显式指 site_perl/${perl.version}
    # 坑2：XS 模块（DateTime 等）装在 site_perl/<version>/<archname>/，同样不自动追加，
    #   archname 由 perl -MConfig 动态获取（平台无关）
    perlEnv="${perl.withPackages (pp: [
      pp.Switch pp.YAMLTiny pp.HashMergeSimple pp.ScalarListUtils pp.ListMoreUtils
      pp.TryTiny pp.DateTime pp.DateTimeTimeZone
    ])}"
    archname=$(${perl}/bin/perl -MConfig -e 'print $Config{archname}')
    # 运行时命令：kasmvncserver 反引号调 cat/hostname/mcookie/uname/whoami/xdpyinfo
    #   （coreutils/hostname/util-linux/xdpyinfo），systemd 的 PATH 不含这些，须 wrapProgram 注入
    wrapProgram $out/bin/kasmvncserver \
      --prefix PERL5LIB : "$out/share/perl5" \
      --prefix PERL5LIB : "$perlEnv/lib/perl5/site_perl/${perl.version}" \
      --prefix PERL5LIB : "$perlEnv/lib/perl5/site_perl/${perl.version}/$archname" \
      --prefix PATH : "${coreutils}/bin:${hostname}/bin:${util-linux}/bin:${xdpyinfo}/bin:${xkbcomp}/bin:${xauth}/bin" \
      --set XKB_BASE "${xkeyboard_config}/share/X11/xkb"
  '';

  meta = {
    description = "KasmVNC: web-based remote desktop (Xvnc + built-in browser client)";
    homepage = "https://github.com/kasmtech/KasmVNC";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
