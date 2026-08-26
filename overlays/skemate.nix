# skemate（自研终端复用服务）分发 overlay
# 二进制托管在 w-apis.qksxin.com/terminal，version/sha256 不再硬编码：
# latest.json 由 builtins.fetchurl 无 hash 动态拉取（每次 eval 重新下载，667B 可忽略），
# 天然跟随官方新版本，无需 flake input / lock / 手动刷新。
# 2026-08 根治：原 flake=false input 方案（skemate-latest）弃用——动态内容被 narHash 锁定，
# 发版后各机器 fetcher-cache 缓存旧内容导致 "mismatch in field 'narHash'"，且 --refresh 对 file input 无效。
# 注意：builtins.fetchurl 无 hash 属 impure 操作，eval 必须 --impure（flake 命令 pure 模式仅此可关）。
# 平台：以 latest.json 的 platforms 键为准（当前 linux-amd64 / darwin-arm64 / linux-arm64），
#       未发布的平台直接 throw

{ lib }:
final: prev: let
  release = builtins.fromJSON (builtins.readFile
    (builtins.fetchurl "https://w-apis.qksxin.com/terminal/latest.json"));
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
        "skemate: latest.json 缺 ${platformKey} 平台条目，请检查 w-apis.qksxin.com/terminal/latest.json");
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
