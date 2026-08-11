# mini-m4 mise 组件声明（wanted.yaml 的 mini_m4.mise 维护）
# dart/flutter 保留实机自定义下载源（googleapis 直连，mise 默认源不可达）
# 注意：接管 config.toml 后，age/fd/ripgrep/rtk/ruby/uv 不再由 mise 管理
#   （fd/ripgrep/rtk 已由 nix 包管理；已安装目录不会被卸载，可 mise uninstall 清理）

{ ... }:
{
  home.file.".config/mise/config.toml".text = ''
    [tools]
    android-sdk = "latest"
    bun = "latest"
    cocoapods = "latest"
    dart = { version = "latest", url = "https://storage.googleapis.com/dart-archive/channels/stable/release/{{ version }}/sdk/dartsdk-{{ os() }}-{{ arch() }}-release.zip", version_expr = 'fromJSON(body).prefixes | filter({ # matches "^channels/stable/release/(\\d+\\.\\d+\\.\\d+)/$" }) | map({split(#, "/")[3]}) | sortVersions()', version_list_url = "https://storage.googleapis.com/storage/v1/b/dart-archive/o?prefix=channels/stable/release/&delimiter=/" }
    flutter = { version = "latest", platforms = { linux-x64 = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_{{ version }}-stable.tar.xz" }, macos-arm64 = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_{{ version }}-stable.zip" }, macos-x64 = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_{{ version }}-stable.zip" }, windows-x64 = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_{{ version }}-stable.zip" } }, version_expr = 'fromJSON(body).releases | filter({ #.channel == "stable" }) | map({ replace(#.version, "-stable", "") }) | sortVersions()', version_list_url = "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json" }
    go = "1.25"
    java = "oracle-17"
    node = "24"
    python = "3.11"

    [env]
    ANDROID_HOME = "/Users/fan/sdk/Android"
  '';
}
