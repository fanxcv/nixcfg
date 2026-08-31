# skemate（自研终端复用服务）分发 overlay
# 二进制托管在 w-apis.qksxin.com/terminal，version/sha256 不硬编码：
# 元数据 latest.json 改为【构建期】获取（不用 flake input 锁 narHash）。
# 背景：官方 latest.json 每次发布都会变更，flake.lock 锁 narHash 后，tarball-ttl 过期时
#       nix 重查发现内容失配，eval 直接报 "mismatch in field 'narHash'" 炸掉整个部署
#       （nix 对 file input 只有手动 flake update 一条路，无自动跟随）。
# 方案：build 期 curl latest.json + jq 解析 version/url/sha256，下载二进制后 sha256sum 校验。
#       每次构建自动跟随官方新版本（零手动，无需 nix flake update；无发布时内容不变，
#       output 为内容寻址，构建结果仍可复用）。URL 取 json 权威字段 platforms.<key>.url
#       （cdn.qksxin.com），不再手工拼接。
# 代价：每次重建需联网拉元数据+二进制，离线不可构建。
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
in
{
  skemate = final.stdenvNoCC.mkDerivation {
    pname = "skemate";
    # 具体版本由构建期 latest.json 决定（eval 期不可读），故固定 unstable
    version = "unstable";

    nativeBuildInputs = [
      final.pkgs.curl
      final.pkgs.jq
      final.pkgs.cacert # 沙箱内 curl 无默认 CA，需显式 --cacert
    ];

    buildCommand = ''
      cacert=${final.pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      meta=$(${final.pkgs.curl}/bin/curl -fsSL --cacert "$cacert" https://w-apis.qksxin.com/terminal/latest.json)
      version=$(echo "$meta" | ${final.pkgs.jq}/bin/jq -r '.version')
      url=$(echo "$meta" | ${final.pkgs.jq}/bin/jq -r '.platforms["${platformKey}"].url')
      sha=$(echo "$meta" | ${final.pkgs.jq}/bin/jq -r '.platforms["${platformKey}"].sha256')
      if [ -z "$url" ] || [ -z "$sha" ]; then
        echo "skemate: latest.json 缺 ${platformKey} 平台条目（version=$version），请检查 w-apis.qksxin.com" >&2
        exit 1
      fi
      echo "===> skemate ${platformKey} 版本 $version（sha256 $sha）"
      mkdir -p "$out/bin"
      ${final.pkgs.curl}/bin/curl -fsSL --cacert "$cacert" "$url" -o "$out/bin/skemate"
      echo "$sha  $out/bin/skemate" | sha256sum -c -
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
