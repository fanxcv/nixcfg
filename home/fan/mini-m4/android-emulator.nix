# 安卓模拟器声明式恢复（emulator + 系统镜像 + AVD）
# ANDROID_HOME 由 mise android-sdk 接管（mise.nix），但 emulator/system-images/AVD
# 是 sdkmanager/avdmanager 的产物（不在 nix store）。本模块在激活期幂等保证它们就位：
# 已装则跳过（不联网不下载），缺失才安装——重装系统/清空 SDK 后一条 nix 命令恢复模拟器。
# AVD 定义对齐实机现状：Pixel_Fold(android-37.0 ps16k)

{ lib, ... }:
{
  home.activation.setupAndroidEmulator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ANDROID_HOME="''${ANDROID_HOME:-/Users/fan/sdk/Android}"
    SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
    AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
    SETUP_LOG="/tmp/android-emulator-setup.log"

    # java 由 mise 提供（config.toml java=oracle-25）；activation 脚本是 sh（不读 .zshenv），
    # PATH 无 ~/.nix-profile/bin（mise 所在），显式补全；shims 供 java 使用
    export PATH="$HOME/.nix-profile/bin:$HOME/.local/share/mise/shims:$PATH"
    if ! command -v java >/dev/null 2>&1; then
      echo "[android-emulator] 未找到 java，尝试 mise install java@oracle-25（首次部署自动补装）..."
      if command -v mise >/dev/null 2>&1 && mise install java@oracle-25 >/dev/null 2>&1; then
        echo "[android-emulator] java 已装（mise oracle-25）；其余组件请手动 mise install"
      else
        echo "警告: mise install java@oracle-25 失败，安卓模拟器声明跳过（先手动 mise install 再重跑激活）"
        exit 0
      fi
    fi
    # sdkmanager 缺失 = Android SDK 未装（mise 组件按需安装，全新环境常见），优雅跳过
    if [ ! -x "$SDKMANAGER" ]; then
      echo "警告: 未找到 sdkmanager（''${SDKMANAGER}），模拟器声明跳过（先 mise install android-sdk 或手动装 SDK 再重跑激活）"
      exit 0
    fi

    # --- emulator + 系统镜像（幂等：目录齐全则跳过，避免每次激活联网检查）---
    if [ -x "$ANDROID_HOME/emulator/emulator" ] \
      && [ -d "$ANDROID_HOME/system-images/android-37.0/google_apis_playstore_ps16k/arm64-v8a" ]; then
      echo "[android-emulator] emulator + 系统镜像已就位"
    else
      yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
      echo "[android-emulator] 安装 emulator + 系统镜像（日志: ''${SETUP_LOG}）"
      if ! "$SDKMANAGER" "emulator" \
          "system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a" \
          >"$SETUP_LOG" 2>&1; then
        echo "错误: sdkmanager 安装失败，日志尾部："
        tail -20 "$SETUP_LOG"
        exit 1
      fi
    fi

    # --- AVD（缺失时重建，device id 与镜像包名对齐实机定义）---
    create_avd() {
      local name="$1" pkg="$2" device="$3"
      if [ -d "$HOME/.android/avd/$name.avd" ]; then
        echo "[android-emulator] AVD $name 已存在"
        return
      fi
      echo no | "$AVDMANAGER" create avd --name "$name" --package "$pkg" --device "$device" --force
      [ -d "$HOME/.android/avd/$name.avd" ] && echo "[android-emulator] AVD $name 已创建"
    }
    create_avd Pixel_Fold "system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a" pixel_fold
  '';
}
