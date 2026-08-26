# skemate（自研终端复用服务）分发 overlay
# 二进制托管在 w-apis.qksxin.com/terminal，version/sha256 不再硬编码：
# latest.json 作为 flake input 锁定（flake.nix 的 skemate-latest，flake=false），
# 此文件在 flake.lock 里锁 narHash，nix flake update 即自动跟随官方新版本。
# 升级流程（scripts/update-skemate.sh 一步完成）：
#   1. 脚本 curl latest.json 取新版本号，改写 flake.nix 的 ?v= 查询参数
#   2. nix flake update skemate-latest   # URL 已变 → 必然重新下载，不走缓存
#   3. 之后各机器 rebuild 即拉到新版本二进制（builtins.fetchurl 按最新 url+sha256 下载）
# 平台：以 latest.json 的 platforms 键为准（当前 linux-amd64 / darwin-arm64 / linux-arm64），
#       未发布的平台直接 throw

{ lib, skemateLatest }:
final: prev: let
  release = builtins.fromJSON (builtins.readFile skemateLatest);
in {
  skemate = final.stdenv.mkDerivation {
    pname = "skemate";
    version = release.version;

    # nix system → 官方下载文件名（latest.json 的 platforms 键）
    src = let
      platformKey = {
        "x86_64-linux" = "linux-amd64";
        "aarch64-darwin" = "darwin-arm64";
        "aarch64-linux" = "linux-arm64";
      }.${final.stdenv.hostPlatform.system} or (throw
        "skemate: 平台 ${final.stdenv.hostPlatform.system} 无官方构建（latest.json platforms 键）");
      info = release.platforms.${platformKey} or (throw
        "skemate: latest.json 缺 ${platformKey} 平台条目，请先 nix flake update skemate-latest");
    in builtins.fetchurl {
      # latest.json 的 url 形如 /0.5.74/skemate-linux-amd64（含 skemate- 前缀）
      url = "https://w-apis.qksxin.com/terminal/${release.version}/skemate-${platformKey}";
      # latest.json 的 sha256 为 hex，builtins.fetchurl 直接接受
      sha256 = info.sha256;
    };

    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/skemate
      runHook postInstall
    '';

    meta = {
      description = "自研终端复用服务（skemate）";
      mainProgram = "skemate";
      platforms = [ "x86_64-linux" "aarch64-darwin" "aarch64-linux" ];
    };
  };
}
