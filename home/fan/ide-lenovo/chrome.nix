# ide-lenovo 专属：Google Chrome 浏览器（远程桌面主浏览器，手动打开，不自启）
# 9222 调试端口：wrapper 包装 chromium，用户手动启动（panel/终端）都带
#   --remote-debugging-port=9222（DevTools 协议，http://127.0.0.1:9222/json/version 验证）
# 坑1：容器 root 跑 Chromium 系必须 --no-sandbox（无 user namespace）
# 坑2：DevTools 远程调试要求非默认数据目录（否则报 requires a non-default data directory）→ --user-data-dir
# 坑3：容器里 Chromium 系偶发 SIGTRAP 崩溃（crashpad 转储失败 tag not found，容器环境）——如需 autostart 保常驻则用循环重启脚本，但本机浏览器手动打开不自启
# 坑4：容器 /dev/shm 仅 64M（Docker 默认）→ Chromium 共享内存不足 SIGTRAP 崩溃（rc=133）→ --disable-dev-shm-usage
# 坑5：无 GPU 容器 GLX 缺失 → GPU 进程初始化失败连锁崩溃 → --disable-gpu（软渲染，已验证 rc 133→稳定）
# 包：nixpkgs google-chrome（unfree，flake.nix mkHomeConfig extraUnfree 放行 "google-chrome"）

{ pkgs, lib, ... }:
let
  chrome = pkgs.google-chrome;
  # 包装脚本：名字叫 chrome，PATH 里唯一入口（不装原包 bin，避免同名冲突）；
  # 包装二元是 chromium（google-chrome 是 chromium wrapper，makeWrapper 到 $out/bin/chromium）
  chromeWrapper = pkgs.writeShellScriptBin "chrome" ''
    exec ${chrome}/bin/chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --remote-debugging-port=9222 --user-data-dir=/root/.config/chrome-debug "$@"
  '';
in
# 仅 x86_64-linux（lenovo 真机架构）；aarch64 上 eval 门控
lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  home.packages = [ chromeWrapper ];

  home.activation.chrome = lib.hm.dag.entryAfter [ "kasmvncBeautify" ] ''
    # ── 1. 不自动开 chrome（用户手动打开；autostart 残留清理，幂等）──
    #    手动打开走 chromeWrapper（PATH 里 chrome），自动带 9222 调试端口/禁 GPU 等参数
    rm -f /root/.config/autostart/chrome.desktop

    # ── 2. 应用菜单项（xfce whisker 菜单可见，图标用 chrome 包自带）──
    mkdir -p /root/.local/share/applications
    cat > /root/.local/share/applications/chrome.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Google Chrome
    Comment=Web Browser
    Exec=${chromeWrapper}/bin/chrome %U
    Icon=${chrome}/share/icons/hicolor/256x256/apps/chromium.png
    Terminal=false
    Categories=Network;WebBrowser;
    StartupWMClass=chromium
    EOF
  '';
}
