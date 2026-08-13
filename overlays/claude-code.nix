# claude-code 分发镜像 overlay
# 官方 CDN（downloads.claude.ai）国内不可达：src 改用 npmmirror 的 npm 平台包
# （@anthropic-ai/claude-code-<platform>，同一份官方二进制，tarball 内 package/claude）
# overlay 无法在 home 模块层注册（pkgs 先于模块构造），由 flake.nix 的 import nixpkgs 注入

{ lib }:
final: prev: {
  claude-code = prev.claude-code.overrideAttrs (old: {
    src = let
      key = "${final.stdenv.hostPlatform.node.platform}-${final.stdenv.hostPlatform.node.arch}";
    in final.fetchurl {
      url = "https://registry.npmmirror.com/@anthropic-ai/claude-code-${key}/-/claude-code-${key}-${old.version}.tgz";
      # 各平台 npm 平台包 tarball 内容不同，hash 必须按平台区分（2.1.223 实测，
      # Anthropic 重发过 npm 包：linux-arm64/darwin-* 已更新，linux-x64 未变）
      sha256 = ({
        "linux-x64" = "sha256-+zNcfFtE/pxbSNFdQcp5A+HQ7SoeqTLaDo9bCfNKGoY=";
        "linux-arm64" = "sha256-KcSexiv76ZXlsTVKTDLRcQEGXSx3ItXQKFz6agjYxEE=";
        "darwin-x64" = "sha256-CbmTP8KxpjSUFDNFmLiBqJYLQc5DUnBdT6p9HHAQ7KE=";
        "darwin-arm64" = "sha256-OdByisHzyNsH5wh0yGwJGuB3JqhI6b28GNUo3ZF31W0=";
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
