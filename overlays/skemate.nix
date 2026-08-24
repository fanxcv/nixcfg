# skemate（自研终端复用服务）分发 overlay
# 二进制托管在 w-apis.qksxin.com/terminal，latest.json 记录各平台版本与 sha256（hex）
# 升级流程：
#   curl -fsSL https://w-apis.qksxin.com/terminal/latest.json   # 查最新 version 与 sha256
#   nix hash convert --hash-algo sha256 --to sri <hex>           # hex → SRI 填入下方
# 平台：latest.json 当前仅 linux-amd64 / darwin-arm64 两个构建，其他平台直接 throw

{ lib }:
final: prev: {
  skemate = final.stdenv.mkDerivation {
    pname = "skemate";
    version = "0.5.73";

    # nix system → 官方下载文件名（latest.json 的 platforms 键）
    src = let
      platformKey = {
        "x86_64-linux" = "linux-amd64";
        "aarch64-darwin" = "darwin-arm64";
      }.${final.stdenv.hostPlatform.system} or (throw
        "skemate: 平台 ${final.stdenv.hostPlatform.system} 无官方构建（latest.json 仅 linux-amd64 / darwin-arm64）");
      hashes = {
        "linux-amd64" = "sha256-rgj8OiVddT+8NmBADxZ5lEguaFvmAHoa7x4ieRS8a14=";
        "darwin-arm64" = "sha256-/mUbw0SbC+sUpVqf4S3doKHjtUmCVDSc+M4uHR73m1E=";
      };
      # 用 builtins.fetchurl（eval 期 nix 下载器）而非 pkgs.fetchurl（构建期 curl builder）：
      # curl builder 带 --continue-at - 断点续传，网络中断时 Range 拼接会产出坏文件
      # （si-11 容器实测 hash mismatch；builtins.fetchurl 下载即校验，构建期只从 store 复制）
    in builtins.fetchurl {
      # latest.json 的 url 形如 /0.5.72/skemate-linux-amd64（含 skemate- 前缀）
      url = "https://w-apis.qksxin.com/terminal/${final.skemate.version}/skemate-${platformKey}";
      sha256 = hashes.${platformKey} or (throw "skemate: ${platformKey} 的 sha256 未记录，请按升级流程填充");
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
      platforms = [ "x86_64-linux" "aarch64-darwin" ];
    };
  };
}
