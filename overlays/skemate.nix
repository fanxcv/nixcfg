# skemate（自研终端复用服务）分发 overlay
# 二进制托管在 w-apis.qksxin.com/terminal，version/url/sha256 来自官方 latest.json：
# 【eval 期】解析（builtins.fetchurl 无 hash 拉取，须 --impure）——三字段全部进入 drv：
#   官方发布新版 → latest.json 内容变 → store 路径变 → drv 变 → 自动重建跟随（零手动，无需 flake update）
#   无发布 → json 内容不变 → drv 不变 → 复用旧构建（不重复下载二进制）
# 代价：eval 必须联网且带 --impure（darwin-rebuild switch --impure / nix build --impure /
#       home-manager switch --impure），纯 eval 直接报 fetchurl 错（比静默用旧版强）。
# 历史：早期在【build 期】curl latest.json（version 恒 "unstable"），drv 输入不变，
#       nix 直接复用旧 output、buildCommand 永不重跑——官方发版后不跟随（假自动），故弃。
# 平台：以 latest.json 的 platforms 键为准（当前 linux-amd64 / darwin-arm64 / linux-arm64），
#       未发布的平台直接构建失败并提示

final: prev:
let
  # nix system → latest.json platforms 键
  platformKey =
    {
      "x86_64-linux" = "linux-amd64";
      "aarch64-darwin" = "darwin-arm64";
      "aarch64-linux" = "linux-arm64";
    }
    .${final.stdenv.hostPlatform.system}
      or (throw "skemate: 平台 ${final.stdenv.hostPlatform.system} 无官方构建（latest.json platforms 键）");
  # eval 期拉取官方元数据（impure fetchurl：内容寻址，json 变则路径变 → drv 变）
  meta = builtins.fromJSON (builtins.readFile (builtins.fetchurl "https://w-apis.qksxin.com/terminal/latest.json"));
  platform =
    meta.platforms.${platformKey}
      or (throw "skemate: latest.json 缺 ${platformKey} 平台条目（version=${meta.version}），请检查 w-apis.qksxin.com");
in
{
  skemate = final.stdenvNoCC.mkDerivation {
    pname = "skemate";
    inherit (meta) version;

    nativeBuildInputs = [
      final.pkgs.curl
      final.pkgs.cacert # 沙箱内 curl 无默认 CA，需显式 --cacert
    ];

    buildCommand = ''
      cacert=${final.pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      mkdir -p "$out/bin"
      ${final.pkgs.curl}/bin/curl -fsSL --cacert "$cacert" "${platform.url}" -o "$out/bin/skemate"
      echo "${platform.sha256}  $out/bin/skemate" | sha256sum -c -
      chmod +x "$out/bin/skemate"
    '';

    meta = {
      description = "自研终端复用服务（skemate）";
      mainProgram = "skemate";
      platforms = [
        "x86_64-linux"
        "aarch64-darwin"
        "aarch64-linux"
      ];
    };
  };
}
