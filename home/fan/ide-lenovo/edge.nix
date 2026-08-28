# ide-lenovo 专属：Microsoft Edge 浏览器（远程桌面主浏览器）
# 9222 调试端口：wrapper 包装 microsoft-edge，任何启动方式（panel/终端/autostart）都带
#   --remote-debugging-port=9222（DevTools 协议，http://127.0.0.1:9222/json/version 验证）
# 坑1：容器 root 跑 Chromium 系必须 --no-sandbox（无 user namespace）
# 坑2：DevTools 远程调试要求非默认数据目录（否则报 requires a non-default data directory）→ --user-data-dir
# 坑3：容器里 edge 偶发 SIGTRAP 崩溃（crashpad 转储失败 tag not found，容器环境）→ autostart 循环重启脚本保常驻
# 坑4：容器 /dev/shm 仅 64M（Docker 默认）→ Chromium 共享内存不足 SIGTRAP 崩溃（rc=133）→ --disable-dev-shm-usage
# 坑5：无 GPU 容器 GLX 缺失 → GPU 进程初始化失败连锁崩溃 → --disable-gpu（软渲染，已验证 rc 133→稳定）
# 包：nixpkgs microsoft-edge（unfree，flake.nix mkHomeConfig extraUnfree 放行）

{ pkgs, lib, ... }:
let
  edge = pkgs.microsoft-edge;
  # 包装脚本：名字也叫 microsoft-edge，PATH 里唯一入口（不装原包 bin，避免同名冲突）
  edgeWrapper = pkgs.writeShellScriptBin "microsoft-edge" ''
    exec ${edge}/bin/microsoft-edge --no-sandbox --disable-gpu --disable-dev-shm-usage --remote-debugging-port=9222 --user-data-dir=/root/.config/edge-debug "$@"
  '';
in
# 仅 x86_64-linux（lenovo 真机架构）；aarch64 上 eval 门控
lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  home.packages = [ edgeWrapper ];

  home.activation.edge = lib.hm.dag.entryAfter [ "kasmvncBeautify" ] ''
    # ── 1. 不自动开 edge（用户手动打开；autostart 残留清理，幂等）──
    #    手动打开走 edgeWrapper（PATH 里 microsoft-edge），自动带 9222 调试端口/禁 GPU 等参数
    rm -f /root/.config/autostart/edge.desktop

    # ── 2. 应用菜单项（xfce whisker 菜单可见，图标用 edge 包自带）──
    mkdir -p /root/.local/share/applications
    cat > /root/.local/share/applications/microsoft-edge.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Microsoft Edge
    Comment=Web Browser
    Exec=${edgeWrapper}/bin/microsoft-edge %U
    Icon=${edge}/share/icons/hicolor/256x256/apps/microsoft-edge.png
    Terminal=false
    Categories=Network;WebBrowser;
    StartupWMClass=microsoft-edge
    EOF
  '';
}
