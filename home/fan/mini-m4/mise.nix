# mini-m4 mise 组件声明（wanted.yaml 的 mini_m4.mise 维护）
# dart/flutter SDK 下载走国内镜像（storage.flutter-io.cn，与 mirrors.nix 的 FLUTTER_STORAGE_BASE_URL 同源）；
#   dart 的 version_list_url（GCS JSON API）无镜像，保留官方直连（仅版本探测，低频小流量）
# 注意：接管 config.toml 后，age/fd/ripgrep/rtk/ruby/uv 不再由 mise 管理
#   （fd/ripgrep/rtk 已由 nix 包管理；已安装目录不会被卸载，可 mise uninstall 清理）
# config.toml 策略（→ _common_/mise/apply.py，实体文件可写）：
#   不存在 → nix 模板创建默认；已存在 → 补齐 nix 指定但缺失的键，已存在键（含版本不同）
#   保留用户版本；用户内容/注释原样；旧 symlink 自动实体化

{ pkgs, lib, ... }:
let
  template = pkgs.writeText "mise-config.toml" ''
    [tools]
    android-sdk = "22.0"   # 显式版本："latest" 解析 bug 落 1.0（2024 老 sdkmanager 解析新仓库丢 emulator 包，2025-08 实测）
    bun = "latest"
    cocoapods = "latest"
    dart = { version = "latest", url = "https://storage.flutter-io.cn/dart-archive/channels/stable/release/{{ version }}/sdk/dartsdk-{{ os() }}-{{ arch() }}-release.zip", version_expr = 'fromJSON(body).prefixes | filter({ # matches "^channels/stable/release/(\\d+\\.\\d+\\.\\d+)/$" }) | map({split(#, "/")[3]}) | sortVersions()', version_list_url = "https://storage.googleapis.com/storage/v1/b/dart-archive/o?prefix=channels/stable/release/&delimiter=/" }
    flutter = { version = "latest", platforms = { linux-x64 = { url = "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/flutter_linux_{{ version }}-stable.tar.xz" }, macos-arm64 = { url = "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_{{ version }}-stable.zip" }, macos-x64 = { url = "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/macos/flutter_macos_{{ version }}-stable.zip" }, windows-x64 = { url = "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_{{ version }}-stable.zip" } }, version_expr = 'fromJSON(body).releases | filter({ #.channel == "stable" }) | map({ replace(#.version, "-stable", "") }) | sortVersions()', version_list_url = "https://storage.flutter-io.cn/flutter_infra_release/releases/releases_linux.json" }
    go = "1.25"
    java = "oracle-25"
    node = "24"
    python = "3"

    # ANDROID_HOME / ANDROID_SDK_ROOT / cmdline-tools PATH 由 android-sdk 插件自动注入；
    # platform-tools（adb/fastboot）与 emulator 不在插件注入范围（实测仅 cmdline-tools），
    # 由 [env] 显式声明：tools=true 仅在 android-sdk 已装时应用，路径经 tools['android-sdk'].path 跟随版本
    [env]
    _.path = { path = ["{{ tools['android-sdk'].path }}/platform-tools", "{{ tools['android-sdk'].path }}/emulator"], tools = true }
    # 交互 shell 由 omz mise 插件 activate 引入，非交互场景显式 eval mise env
  '';
in
{
  home.activation.setupMiseConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 ${./../_common_/mise/apply.py} \
      "$HOME/.config/mise/config.toml" "${template}"
  '';
}
