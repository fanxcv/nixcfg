# ide-lenovo 专属：Google Chrome 浏览器（远程桌面主浏览器，autostart 自启 + 守护保活）
# 9222 调试端口：wrapper 包装 chromium，手动启动（panel/终端/autostart）都带
#   --remote-debugging-port=9222（DevTools 协议，http://127.0.0.1:9222/json/version 验证）
# 自启：~/.config/autostart/chrome.desktop → chrome-guard（循环保活）；
#   桌面实例常驻 127.0.0.1:9222 后，容器内 MCP（chrome-devtools --browser-url http://127.0.0.1:9222）
#   连的是桌面实例；否则 MCP 在无 browser-url 的配置下会自起 headless 抢走该端口
# 坑1：容器 fan 跑 Chromium 系必须 --no-sandbox（无 user namespace）；提示条由 --test-type 抑制（Chromium issue 40205764），不改变沙箱状态
# 坑2：DevTools 远程调试要求非默认数据目录（否则报 requires a non-default data directory）→ --user-data-dir；此目录即唯一主 profile（书签/登录所在）
# 坑3：容器里 Chromium 系偶发 SIGTRAP 崩溃（crashpad 转储失败 tag not found，容器环境）→ autostart 走 chrome-guard 循环重启保常驻
# 坑4：容器 /dev/shm 仅 64M（Docker 默认）→ Chromium 共享内存不足 SIGTRAP 崩溃（rc=133）→ --disable-dev-shm-usage
# 坑5：无 GPU 容器 GLX 缺失 → GPU 进程初始化失败连锁崩溃 → --disable-gpu（软渲染，已验证 rc 133→稳定）
# 包：nixpkgs google-chrome（unfree，flake.nix 放行 "google-chrome"）

{ pkgs, lib, ... }:
let
  # 桌面会话 home（KasmVNC 会话迁 fan）：显式常量，避免依赖 identity.nix 落地
  sessionHome = "/home/fan";
  # 容器构建文件系统不允许恢复 deb 内 chrome-sandbox 的 setuid 位；运行时已显式 --no-sandbox。
  chrome = pkgs.google-chrome.overrideAttrs (old: {
    unpackPhase =
      lib.replaceStrings [ "tar xf data.tar.xz" ] [ "tar --no-same-permissions -xf data.tar.xz" ]
        old.unpackPhase;
  });
  # 仅暴露 chrome 入口，避免原包命令名进入 PATH。
  chromeWrapper = pkgs.writeShellScriptBin "chrome" ''
    exec ${chrome}/bin/google-chrome-stable --no-sandbox --disable-gpu --disable-dev-shm-usage --remote-debugging-port=9222 --user-data-dir=${sessionHome}/.config/chrome --test-type "$@"
  '';
  # autostart 守护：DevTools 端口无响应才拉起 chrome（已在跑则空转），崩溃后自动重启
  chromeGuard = pkgs.writeShellScriptBin "chrome-guard" ''
    log="''${HOME}/.cache/chrome-guard.log"
    mkdir -p "''${log%/*}"
    while :; do
      if ! ${pkgs.curl}/bin/curl -sf --max-time 2 http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
        echo "[$(date '+%F %T')] 启动 chrome（DevTools 9222 无响应）" >> "$log"
        ${chromeWrapper}/bin/chrome >> "$log" 2>&1
        rc=$?
        echo "[$(date '+%F %T')] chrome 退出 rc=$rc" >> "$log"
      fi
      sleep 3
    done
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
    categories = [
      "Network"
      "WebBrowser"
    ];
    startupWMClass = "chromium";
  };
in
# 仅 x86_64-linux（lenovo 真机架构）；aarch64 上 eval 门控
lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  home.packages = [
    chromeWrapper
    chromeGuard
  ];

  home.activation.chrome = lib.hm.dag.entryAfter [ "kasmvncBeautify" ] ''
    # ── 1. autostart：chrome 自启（chrome-guard 保活）；清理旧 Edge 残留（幂等）──
    mkdir -p ${sessionHome}/.config/autostart
    cat > ${sessionHome}/.config/autostart/chrome.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Google Chrome
    Comment=Remote desktop browser with DevTools on 9222
    Exec=${chromeGuard}/bin/chrome-guard
    Terminal=false
    X-GNOME-Autostart-enabled=true
    EOF
    rm -f \
      ${sessionHome}/.config/autostart/microsoft-edge.desktop \
      ${sessionHome}/.local/share/applications/microsoft-edge.desktop \
      ${sessionHome}/.config/plank/dock1/launchers/edge.dockitem

    # ── 2. 应用菜单项：symlink 到 store 桌面项（xfce whisker 菜单可见，与 dock 同源不漂移）──
    mkdir -p ${sessionHome}/.local/share/applications
    ln -sfn ${chromeDesktop}/share/applications/google-chrome.desktop ${sessionHome}/.local/share/applications/chrome.desktop

    # ── 3. 图标：hicolor 主题目录 symlink 到 user icons，使图标名 google-chrome 可解析 ──
    mkdir -p ${sessionHome}/.local/share/icons
    ln -sfn ${chrome}/share/icons/hicolor ${sessionHome}/.local/share/icons/hicolor

    # ── 4. Plank dock 固定 chrome：Launcher 指 store 内 .desktop（永不缺失 → 不被 Plank 自动删除）──
    #     其余 3 个（thunar/terminal/mousepad）由 kasmvnc.nix 写入
    mkdir -p ${sessionHome}/.config/plank/dock1/launchers
    cat > ${sessionHome}/.config/plank/dock1/launchers/chrome.dockitem <<EOF
    [PlankDockItemPreferences]
    Launcher=file://${chromeDesktop}/share/applications/google-chrome.desktop
    EOF
  '';
}
