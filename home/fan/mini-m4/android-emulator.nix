# 安卓模拟器声明式恢复（emulator + 系统镜像 + AVD）
# ANDROID_HOME 由 mise android-sdk 接管（mise.nix），但 emulator/system-images/AVD
# 是 sdkmanager/avdmanager 的产物（不在 nix store）。本模块在激活期幂等保证工具链就位：
#   java / android-sdk（cmdline-tools）由 mise 自动补装（首次联网，幂等秒过）
#   emulator / system-images 只声明不下载（镜像巨大，按需手动 sdkmanager 安装）
#   AVD 在镜像就位后创建（Pixel_Fold(android-37.0 ps16k)）
# 重装系统/清空 SDK 后一条 nix 命令恢复工具链；镜像/AVD 装好后同样自动恢复

{ lib, ... }:
{
  home.activation.setupAndroidEmulator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export ANDROID_HOME="''${ANDROID_HOME:-/Users/fan/sdk/Android}"
    # java 由 mise 提供（config.toml java=oracle-25）；activation 脚本是 sh（不读 .zshenv），
    # PATH 无 ~/.nix-profile/bin（mise 所在），显式补全；shims 供 java 使用
    export PATH="$HOME/.nix-profile/bin:$HOME/.local/share/mise/shims:$PATH"
    # mise 的 android-sdk 装在 installs/android-sdk/<ver>/cmdline-tools/<ver>/bin/（版本目录，非 latest），动态定位
    MISE_ASDK="$(command -v mise >/dev/null 2>&1 && mise where android-sdk 2>/dev/null || true)"
    SDKMANAGER="$(ls "$MISE_ASDK"/cmdline-tools/*/bin/sdkmanager 2>/dev/null | head -1)"
    AVDMANAGER="$(ls "$MISE_ASDK"/cmdline-tools/*/bin/avdmanager 2>/dev/null | head -1)"
    if ! command -v java >/dev/null 2>&1; then
      echo "[android-emulator] 未找到 java，尝试 mise install java@oracle-25（首次部署自动补装）..."
      if command -v mise >/dev/null 2>&1 && mise install java@oracle-25 >/dev/null 2>&1; then
        echo "[android-emulator] java 已装（mise oracle-25）；其余组件请手动 mise install"
      else
        echo "警告: mise install java@oracle-25 失败，安卓模拟器声明跳过（先手动 mise install 再重跑激活）"
        exit 0
      fi
    fi
    # sdkmanager 缺失 = android-sdk 组件未装 → mise 自动补装（幂等，已装秒过），装后重新定位
    if [ -z "$SDKMANAGER" ] || [ ! -x "$SDKMANAGER" ]; then
      echo "[android-emulator] 未找到 sdkmanager，尝试 mise install android-sdk（首次部署自动补装）..."
      if command -v mise >/dev/null 2>&1 && mise install android-sdk >/dev/null 2>&1; then
        MISE_ASDK="$(mise where android-sdk 2>/dev/null)"
        SDKMANAGER="$(ls "$MISE_ASDK"/cmdline-tools/*/bin/sdkmanager 2>/dev/null | head -1)"
        AVDMANAGER="$(ls "$MISE_ASDK"/cmdline-tools/*/bin/avdmanager 2>/dev/null | head -1)"
        echo "[android-emulator] android-sdk 已装（''${SDKMANAGER}）"
      fi
      if [ -z "$SDKMANAGER" ] || [ ! -x "$SDKMANAGER" ]; then
        echo "警告: mise install android-sdk 后仍找不到 sdkmanager，模拟器声明跳过（先手动 mise install android-sdk 再重跑激活）"
        exit 0
      fi
    fi

    # --- emulator + 系统镜像（只声明不下载：镜像巨大，缺失时按需手动安装）---
    if [ -x "$ANDROID_HOME/emulator/emulator" ] \
      && [ -d "$ANDROID_HOME/system-images/android-37.0/google_apis_playstore_ps16k/arm64-v8a" ]; then
      echo "[android-emulator] emulator + 系统镜像已就位"
    else
      echo "[android-emulator] emulator/system-images 未装，跳过（不自动下载；手动安装: \"$SDKMANAGER\" emulator system-images;android-37.0;google_apis_playstore_ps16k;arm64-v8a）"
      exit 0
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
