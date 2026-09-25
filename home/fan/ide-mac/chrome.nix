# ide-mac 专属：浏览器（远程桌面主浏览器，手动打开，不自启）
# 9222 调试端口：wrapper 包装浏览器，用户手动启动（panel/终端）都带
#   --remote-debugging-port=9222（DevTools 协议，http://127.0.0.1:9222/json/version 验证）
# 架构：x86_64-linux 用 nixpkgs google-chrome（unfree，flake.nix 放行）；
#   aarch64-linux（本机）nixpkgs 无 google-chrome → 用 chromium（hydraPlatforms 含 aarch64-linux）
# 坑1：容器 root 跑 Chromium 系必须 --no-sandbox（无 user namespace）
# 坑2：DevTools 远程调试要求非默认数据目录（否则报 requires a non-default data directory）→ --user-data-dir
# 坑3：容器里 Chromium 系偶发 SIGTRAP 崩溃（crashpad 转储失败 tag not found，容器环境）——如需 autostart 保常驻则用循环重启脚本，但本机浏览器手动打开不自启
# 坑4：容器 /dev/shm 仅 64M（Docker 默认）→ Chromium 共享内存不足 SIGTRAP 崩溃（rc=133）→ --disable-dev-shm-usage
# 坑5：无 GPU 容器 GLX 缺失 → GPU 进程初始化失败连锁崩溃 → --disable-gpu（软渲染，已验证 rc 133→稳定）

{ pkgs, lib, ... }:
let
  isX86 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  browser =
    if isX86 then
      # 容器构建文件系统不允许恢复 deb 内 chrome-sandbox 的 setuid 位；运行时已显式 --no-sandbox。
      pkgs.google-chrome.overrideAttrs (old: {
        unpackPhase =
          lib.replaceStrings [ "tar xf data.tar.xz" ] [ "tar --no-same-permissions -xf data.tar.xz" ]
            old.unpackPhase;
      })
    else
      pkgs.chromium;
  browserBin = if isX86 then "${browser}/bin/google-chrome-stable" else "${browser}/bin/chromium";
  browserName = if isX86 then "Google Chrome" else "Chromium";
  # 仅暴露 chrome 入口，避免原包命令名进入 PATH。
  chromeWrapper = pkgs.writeShellScriptBin "chrome" ''
    exec ${browserBin} --no-sandbox --disable-gpu --disable-dev-shm-usage --remote-debugging-port=9222 --user-data-dir=/root/.config/chrome-debug "$@"
  '';
in
# 仅 Linux（本机 aarch64-linux，浏览器按架构分支）；darwin 等门控跳过
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  home.packages = [ chromeWrapper ];

  home.activation.chrome = lib.hm.dag.entryAfter [ "kasmvncBeautify" ] ''
    # ── 1. 不自动开浏览器，清理旧 Edge 残留（幂等）──
    rm -f \
      /root/.config/autostart/chrome.desktop \
      /root/.config/autostart/microsoft-edge.desktop \
      /root/.local/share/applications/microsoft-edge.desktop \
      /root/.config/plank/dock1/launchers/edge.dockitem

    # ── 2. 应用菜单项（xfce whisker 菜单可见，图标用浏览器包自带）──
    mkdir -p /root/.local/share/applications
    cat > /root/.local/share/applications/chrome.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=${browserName}
    Comment=Web Browser
    Exec=${chromeWrapper}/bin/chrome %U
    Icon=${browser}/share/icons/hicolor/256x256/apps/chromium.png
    Terminal=false
    Categories=Network;WebBrowser;
    StartupWMClass=chromium
    EOF
  '';
}
