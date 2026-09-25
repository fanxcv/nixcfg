# ide-lenovo 专属：Google Chrome 浏览器（远程桌面主浏览器，手动打开，不自启）
# 9222 调试端口：wrapper 包装 chromium，用户手动启动（panel/终端）都带
#   --remote-debugging-port=9222（DevTools 协议，http://127.0.0.1:9222/json/version 验证）
# 坑1：容器 root 跑 Chromium 系必须 --no-sandbox（无 user namespace）
# 坑2：DevTools 远程调试要求非默认数据目录（否则报 requires a non-default data directory）→ --user-data-dir
# 坑3：容器里 Chromium 系偶发 SIGTRAP 崩溃（crashpad 转储失败 tag not found，容器环境）——如需 autostart 保常驻则用循环重启脚本，但本机浏览器手动打开不自启
# 坑4：容器 /dev/shm 仅 64M（Docker 默认）→ Chromium 共享内存不足 SIGTRAP 崩溃（rc=133）→ --disable-dev-shm-usage
# 坑5：无 GPU 容器 GLX 缺失 → GPU 进程初始化失败连锁崩溃 → --disable-gpu（软渲染，已验证 rc 133→稳定）
# 包：nixpkgs google-chrome（unfree，flake.nix 放行 "google-chrome"）

{ pkgs, lib, ... }:
let
  # 容器构建文件系统不允许恢复 deb 内 chrome-sandbox 的 setuid 位；运行时已显式 --no-sandbox。
  chrome = pkgs.google-chrome.overrideAttrs (old: {
    unpackPhase = lib.replaceStrings
      [ "tar xf data.tar.xz" ]
      [ "tar --no-same-permissions -xf data.tar.xz" ]
      old.unpackPhase;
  });
  # 仅暴露 chrome 入口，避免原包命令名进入 PATH。
  chromeWrapper = pkgs.writeShellScriptBin "chrome" ''
    exec ${chrome}/bin/google-chrome-stable --no-sandbox --disable-gpu --disable-dev-shm-usage --remote-debugging-port=9222 --user-data-dir=/root/.config/chrome-debug "$@"
  '';
  # store 内桌面项：Plank 的 dockitem Launcher 指向它 → 路径永不缺失，不会被 Plank 自动删除
  # 图标名 google-chrome：nixpkgs google-chrome installPhase 把 product_logo_*.png 装为
  #   $out/share/icons/hicolor/<size>x<size>/apps/google-chrome.png（证据见 .pi/subagents/artifacts/ide-dock-font.md）
  chromeDesktop = pkgs.makeDesktopItem {
    name = "google-chrome";
    desktopName = "Google Chrome";
    exec = "${chromeWrapper}/bin/chrome %U";
    icon = "google-chrome";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
    startupWMClass = "chromium";
  };
in
# 仅 x86_64-linux（lenovo 真机架构）；aarch64 上 eval 门控
lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  home.packages = [ chromeWrapper ];

  home.activation.chrome = lib.hm.dag.entryAfter [ "kasmvncBeautify" ] ''
    # ── 1. 不自动开 chrome，清理旧 Edge 残留（幂等）──
    rm -f \
      /root/.config/autostart/chrome.desktop \
      /root/.config/autostart/microsoft-edge.desktop \
      /root/.local/share/applications/microsoft-edge.desktop \
      /root/.config/plank/dock1/launchers/edge.dockitem

    # ── 2. 应用菜单项：symlink 到 store 桌面项（xfce whisker 菜单可见，与 dock 同源不漂移）──
    mkdir -p /root/.local/share/applications
    ln -sfn ${chromeDesktop}/share/applications/google-chrome.desktop /root/.local/share/applications/chrome.desktop

    # ── 3. 图标：hicolor 主题目录 symlink 到 user icons，使图标名 google-chrome 可解析 ──
    mkdir -p /root/.local/share/icons
    ln -sfn ${chrome}/share/icons/hicolor /root/.local/share/icons/hicolor

    # ── 4. Plank dock 固定 chrome：Launcher 指 store 内 .desktop（永不缺失 → 不被 Plank 自动删除）──
    #     其余 3 个（thunar/terminal/mousepad）由 kasmvnc.nix 写入
    mkdir -p /root/.config/plank/dock1/launchers
    cat > /root/.config/plank/dock1/launchers/chrome.dockitem <<EOF
    [PlankDockItemPreferences]
    Launcher=file://${chromeDesktop}/share/applications/google-chrome.desktop
    EOF
  '';
}
