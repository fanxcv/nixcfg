# codex 官方 GitHub Release 预编译包（静态自包含二进制，免源码编译）
# 为什么不用 nixpkgs 的 codex（pkgs.repos.unstable.codex）：它是 rustPlatform.buildRustPackage 源码构建。
#   x86_64-linux 有 cache.nixos.org 成品，但 aarch64-linux 常态缺货（唯一有货的 nix-community.cachix
#   的 narinfo 被 nix 拒签），于是每次 flake update 后都要在 8GB 容器里编数十分钟 Rust（实测 48 分钟仍在编）。
# 为什么不用官方 flake：outputHashes 与 Cargo.lock 持续失同步（#7863/#7759），2026-09 实测 0.153.4 求值即崩。
# 本包直接取官方 release 资产 codex-package-<target>.tar.gz（静态、自带 rg/bwrap/voice-host/zsh），解包即用。
#
# 版本升级：改 version 与下方 hash。取法：
#   curl -sL https://github.com/openai/codex/releases/download/rust-v<ver>/codex-package_SHA256SUMS
#   取 codex-package-<target>.tar.gz 行的 hex → nix hash convert --hash-algo sha256 --to sri <hex>
# 网络：release 资产直连国内不稳；主 URL 走 ghfast.top 镜像，官方作备用（fetchurl 按序尝试）
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "0.162.1";

  # system → 官方 target 三元组 + tarball hash（SRI）
  assets = {
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-U6nOC5S+snpj/esvdwTZUZnheziYqjO2BGGhqTrA2Is=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-pnb1ciquDYbL43ZDMvCOqx/didwKMAs61P+/SGEfo+M=";
    };
  };

  system = stdenvNoCC.hostPlatform.system;
  asset =
    assets.${system}
      or (throw "codex-bin: 无 ${system} 的官方预编译包（现有：${lib.concatStringsSep ", " (lib.attrNames assets)}）");
  file = "codex-package-${asset.target}.tar.gz";
in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    urls = [
      "https://ghfast.top/https://github.com/openai/codex/releases/download/rust-v${version}/${file}"
      "https://github.com/openai/codex/releases/download/rust-v${version}/${file}"
    ];
    hash = asset.hash;
  };

  # tar 顶层是 bin/ codex-path/ codex-resources/ codex-package.json（多条目，须显式 sourceRoot，
  # 否则默认 unpackPhase 报 "unpacker produced multiple directories"）
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  # 静态 musl 二进制，勿 strip/patchelf（ELF 改动会破坏官方包）
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r bin codex-path codex-resources codex-package.json $out/
    runHook postInstall
  '';

  meta = {
    description = "Codex CLI (official prebuilt release, static self-contained)";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    platforms = lib.attrNames assets;
    mainProgram = "codex";
  };
}
