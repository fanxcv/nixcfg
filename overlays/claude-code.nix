# claude-code 分发镜像 overlay
# 官方 CDN（downloads.claude.ai）国内不可达：src 改用 npmmirror 的 npm 平台包
# （@anthropic-ai/claude-code-<platform>，同一份官方二进制，tarball 内 package/claude）
# overlay 无法在 home 模块层注册（pkgs 先于模块构造），由 flake.nix 的 import nixpkgs 注入

{ lib }:
final: prev: {
  claude-code = prev.claude-code.overrideAttrs (old: {
    src = final.fetchurl {
      url = let
        key = "${final.stdenv.hostPlatform.node.platform}-${final.stdenv.hostPlatform.node.arch}";
      in "https://registry.npmmirror.com/@anthropic-ai/claude-code-${key}/-/claude-code-${key}-${old.version}.tgz";
      # 各平台 npm 平台包 tarball 内容不同，hash 必须按平台区分（2.1.226 全部实测）
      sha256 = ({
        "linux-x64" = "sha256-087pXoakMsjXy5SWvCbsNTeAjh6oXoIHBxy6PTSYPX8=";
        "linux-arm64" = "sha256-+7smENr/cNEYyN2orv/ukrOPIKpGTnWMPQnjyDq271Y=";
        "darwin-x64" = "sha256-9yNzWwDWkqv097nRQe9iNv7gGZy11iuRxfNNKHIoHoY=";
        "darwin-arm64" = "sha256-88qgfBM9i7VA61m1aYVVLxhiOBSAUDaBev4fgJgqv50=";
      }).${key} or (throw "claude-code: 平台 ${key} 的 tarball hash 未记录，先用 nix-prefetch-url 获取后填入 overlays/claude-code.nix");
    };
    dontUnpack = false;
    sourceRoot = "package";
    # 原 installPhase 以 $src 为裸二进制，npm tgz 需解包后 install，wrapProgram 逻辑照抄 nixpkgs
    installPhase = ''
      runHook preInstall
      installBin claude
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
