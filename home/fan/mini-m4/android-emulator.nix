# 安卓模拟器声明式恢复（platform-tools + emulator + 系统镜像 + AVD）
# ANDROID_HOME 由 mise android-sdk 接管（mise.nix），但 platform-tools/emulator/system-images/AVD
# 是 sdkmanager/avdmanager 的产物（不在 nix store）。本模块在激活期幂等保证全部就位：
#   java / android-sdk（cmdline-tools）由 mise 自动补装；platform-tools/emulator/system-images 由
#   sdkmanager 自动安装（均首次联网下载，已装则秒过）
# AVD 在镜像就位后创建（Pixel_Fold(android-37.0 ps16k)）；重装系统/清空 SDK 后一条 nix 命令恢复

{ lib, ... }:
{
  home.activation.setupAndroidEmulator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # 激活环境是 sh（不读 .zshenv），PATH 无 ~/.nix-profile/bin（mise 所在），显式补全
    export PATH="$HOME/.nix-profile/bin:$HOME/.local/share/mise/shims:/usr/bin:/bin:$PATH"
    # mise env：交互 shell 由 omz mise 插件 activate（hook 只在交互 prompt 触发），
    # 非交互激活环境显式加载——JAVA_HOME/ANDROID_HOME/工具 PATH 全由插件自动注入，
    # 失败即中断（mise 是 nix 包必然存在；工具未装时后续分支处理）
    eval "$(mise env)"
    # sdkmanager/emulator/镜像落在 mise 的 android-sdk 目录；ANDROID_HOME 由插件注入（mise env），
    # 工具未安装时回退 mise where 定位；cmdline-tools 优先 latest 链接（旧版本残留时避免命中老 sdkmanager）
    MISE_ASDK="''${ANDROID_HOME:-$(mise where android-sdk 2>/dev/null)}"
    SDKMANAGER="$(ls "$MISE_ASDK"/cmdline-tools/latest/bin/sdkmanager 2>/dev/null || ls "$MISE_ASDK"/cmdline-tools/*/bin/sdkmanager 2>/dev/null | head -1)"
    AVDMANAGER="$(ls "$MISE_ASDK"/cmdline-tools/*/bin/avdmanager 2>/dev/null | head -1)"
    SETUP_LOG="/tmp/android-emulator-setup.log"
    if ! command -v java >/dev/null 2>&1 && [ ! -x "$JAVA_HOME/bin/java" ]; then
      echo "[android-emulator] 未找到 java，尝试 mise install java@oracle-21（首次部署自动补装）..."
      if command -v mise >/dev/null 2>&1 && mise install java@oracle-21 >/dev/null 2>&1; then
        eval "$(mise env)"
        echo "[android-emulator] java 已装（mise oracle-21）；其余组件请手动 mise install"
      else
        echo "警告: mise install java@oracle-21 失败，安卓模拟器声明跳过（先手动 mise install 再重跑激活）"
        exit 0
      fi
    fi
    # sdkmanager 缺失 = android-sdk 组件未装 → mise 自动补装（幂等，已装秒过），装后重新定位
    if [ -z "$SDKMANAGER" ] || [ ! -x "$SDKMANAGER" ]; then
      echo "[android-emulator] 未找到 sdkmanager，尝试 mise install android-sdk（首次部署自动补装）..."
      if command -v mise >/dev/null 2>&1 && mise install android-sdk >/dev/null 2>&1; then
        MISE_ASDK="$(mise where android-sdk 2>/dev/null)"
        SDKMANAGER="$(ls "$MISE_ASDK"/cmdline-tools/latest/bin/sdkmanager 2>/dev/null || ls "$MISE_ASDK"/cmdline-tools/*/bin/sdkmanager 2>/dev/null | head -1)"
        AVDMANAGER="$(ls "$MISE_ASDK"/cmdline-tools/*/bin/avdmanager 2>/dev/null | head -1)"
        echo "[android-emulator] android-sdk 已装（''${SDKMANAGER}）"
      fi
      if [ -z "$SDKMANAGER" ] || [ ! -x "$SDKMANAGER" ]; then
        echo "警告: mise install android-sdk 后仍找不到 sdkmanager，模拟器声明跳过（先手动 mise install android-sdk 再重跑激活）"
        exit 0
      fi
    fi

    # --- platform-tools（adb/fastboot，缺失则 sdkmanager 自动安装；mise [env] 注入 PATH）---
    if [ -x "$MISE_ASDK/platform-tools/adb" ]; then
      echo "[android-emulator] platform-tools 已就位（adb）"
    else
      yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
      echo "[android-emulator] 安装 platform-tools（日志: ''${SETUP_LOG}，首次需下载）"
      if ! "$SDKMANAGER" "platform-tools" >>"$SETUP_LOG" 2>&1; then
        echo "错误: platform-tools 安装失败，日志尾部："
        tail -20 "$SETUP_LOG"
        exit 1
      fi
    fi

    # --- emulator + 系统镜像（缺失则 sdkmanager 自动安装，幂等：齐全则跳过避免每次联网检查）---
    # 镜像版本：android-36（ps16k 是 Android 16 的 16KB 页镜像，最高到 android-36；android-37.0 不存在，2025-08 实测）
    if [ -x "$MISE_ASDK/emulator/emulator" ] \
      && [ -d "$MISE_ASDK/system-images/android-36/google_apis_playstore_ps16k/arm64-v8a" ]; then
      echo "[android-emulator] emulator + 系统镜像已就位"
    else
      yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
      echo "[android-emulator] 安装 emulator + 系统镜像（日志: ''${SETUP_LOG}，首次需下载）"
      if ! "$SDKMANAGER" "emulator" \
          "system-images;android-36;google_apis_playstore_ps16k;arm64-v8a" \
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
    create_avd Pixel_Fold "system-images;android-36;google_apis_playstore_ps16k;arm64-v8a" pixel_fold
  '';
}
