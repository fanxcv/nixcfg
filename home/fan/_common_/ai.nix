# AI 工具二进制（全平台）：beads
# beads（bd）→ Go 单二进制，官方 release 直接分发（fetchurl，不经 npm/编译）
# 其他 AI 工具各归各文件：claude-code + ccline → claude.nix，codex → codex.nix，pi → pi.nix

{ pkgs, tools, ... }:                       # GitHub 加速前缀/开关从集中配置 tools/config.nix 读（tools.githubUrl）
let

  # 平台标识：nix 的 isx86_64/isAarch64 对应官方分发后缀 x64/arm64（beads 的 Go 命名是 amd64）
  os = if pkgs.stdenv.hostPlatform.isLinux then "linux"
    else if pkgs.stdenv.hostPlatform.isDarwin then "darwin"
    else throw "unsupported os: ${pkgs.stdenv.hostPlatform.system}";
  arch = if pkgs.stdenv.hostPlatform.isAarch64 then "arm64"
    else if pkgs.stdenv.hostPlatform.isx86_64 then "x64"
    else throw "unsupported arch: ${pkgs.stdenv.hostPlatform.system}";
  goArch = if arch == "x64" then "amd64" else arch;
  platKey = "${os}-${arch}";
  # 未验证平台的 sha256 先占位，首次构建会报 hash mismatch（报错信息即真实值），填入即可
  placeholderHash = "sha256-0000000000000000000000000000000000000000000=";

  # ---- beads（bd）：Go 单二进制，官方 release 分发包（tar.gz 内含 bd）----
  beads = pkgs.stdenv.mkDerivation {
    pname = "beads";
    version = "1.1.2";
    src = pkgs.fetchurl {
      url = tools.githubUrl "https://github.com/gastownhall/beads/releases/download/v1.1.2/beads_1.1.2_${os}_${goArch}.tar.gz";
      sha256 = {
        "linux-arm64"   = "sha256-oTQBX69L4KQ/hoGo1gLq8LfCVclX8J08kzJXyMkv3RA=";
        "linux-x64"     = "sha256-py1x7TdJVdyfg6D5C1S9e2oAFnCd0Wdq4uNoZR7UAcI=";
        "darwin-arm64"  = "sha256-mwE3qDoq/TQ+Kr0qUGvnLqAychAA92Zpws+Bcp54UB0=";
        "darwin-x64"    = placeholderHash; # TODO: 首次构建时填入
      }.${platKey};
    };
    # tar.gz 内文件在根（无顶层目录），强制 sourceRoot 为解包目录
    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 bd $out/bin/bd
      ln -s bd $out/bin/beads
      runHook postInstall
    '';
    meta = {
      description = "beads (bd) - Memory upgrade for your coding agent";
      homepage = "https://github.com/gastownhall/beads";
      license = pkgs.lib.licenses.mit;
    };
  };
in
{
  # beads 以 Dolt 为存储后端（嵌入式/独立 server 均需 dolt CLI 管理），随 beads 一并安装
  home.packages = [ beads pkgs.dolt ];
}
