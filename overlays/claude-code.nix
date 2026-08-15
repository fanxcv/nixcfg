# claude-code 分发镜像 overlay
# 官方 CDN（downloads.claude.ai）国内不可达：改用 npmmirror 的 npm 平台包
# （@anthropic-ai/claude-code-<platform>，同一份官方二进制，tarball 内 package/claude）
# 免 hash 维护：npm 平台包每次版本升级/重发 hash 都会变（2.1.227/2.1.228 实测 Anthropic 重发过），
# 手动 prefetch 成本高 → 构建时联网下载（不声明 sha256 = 非 FOD，无 hash 校验）。
# 版本仍跟随 nixpkgs unstable（old.version）：nix flake update 后重新构建即自动拉新版，永不 mismatch。
# 前提：构建可联网（__noChroot 已声明：darwin 原版即有；Linux 需 root 构建或沙箱关闭）
# overlay 无法在 home 模块层注册（pkgs 先于模块构造），由 flake.nix 的 import nixpkgs 注入

{ lib }:
final: prev: {
  claude-code = prev.claude-code.overrideAttrs (old: let
    # 平台标识：nix 的 node.platform/arch 对应 npm 平台包后缀（darwin-arm64 / linux-x64 / ...）
    key = "${final.stdenv.hostPlatform.node.platform}-${final.stdenv.hostPlatform.node.arch}";
  in {
    src = null;
    dontUnpack = true;
    # 构建时下载需要非沙箱（FOD 之外唯一联网途径）；darwin 原版 __noChroot 仅限 darwin，Linux 一并放开
    __noChroot = true;
    # 原版 installPhase 以 $src 为裸二进制；npm tgz 需下载解包后 install，curl + cacert 显式入 nativeBuildInputs
    # （darwin 构建环境无系统 CA 文件，SSL_CERT_FILE 必须指向 cacert 包）
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.curl final.cacert ];
    installPhase = ''
      runHook preInstall
      workdir=$(mktemp -d)
      export SSL_CERT_FILE=${final.cacert}/etc/ssl/certs/ca-bundle.crt
      ${final.curl}/bin/curl -fsSL --retry 3 -o "$workdir/claude.tgz" \
        "https://registry.npmmirror.com/@anthropic-ai/claude-code-${key}/-/claude-code-${key}-${old.version}.tgz"
      tar xzf "$workdir/claude.tgz" -C "$workdir" --strip-components=1
      installBin "$workdir/claude"
      wrapProgram $out/bin/claude \
        --set DISABLE_AUTOUPDATER 1 \
        --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
        --set DISABLE_INSTALLATION_CHECKS 1 \
        --set USE_BUILTIN_RIPGREP 0 \
        ${lib.optionalString final.stdenv.hostPlatform.isLinux ''
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ final.alsa-lib ]} \
        ''}--prefix PATH : ${
          lib.makeBinPath (
            [
              final.procps
              final.ripgrep
            ]
            ++ lib.optionals final.stdenv.hostPlatform.isLinux [
              final.bubblewrap
              final.socat
            ]
          )
        }
      runHook postInstall
    '';
  });
}
