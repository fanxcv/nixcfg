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
  # 常驻脚本：edge 崩溃（容器 crashpad 偶发 SIGTRAP）后 3 秒自动重启，保证 9222 一直在
  # 坑：while true 无脑循环会把用户手动关闭的 edge 也拉起（正常退出 rc=0）→ 仅崩溃（rc≠0）才重启
  edgeRun = pkgs.writeShellScriptBin "edge-run" ''
    while true; do
      ${edgeWrapper}/bin/microsoft-edge
      rc=$?
      # 正常退出（用户手动关闭）不重启；崩溃（SIGTRAP 等非零）3 秒后自愈
      [ "$rc" -eq 0 ] && exit 0
      sleep 3
    done
  '';
in
# 仅 x86_64-linux（lenovo 真机架构）；aarch64 上 eval 门控
lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  home.packages = [ edgeWrapper edgeRun ];

  home.activation.edge = lib.hm.dag.entryAfter [ "kasmvncBeautify" ] ''
    # ── 1. autostart：登录自动开 edge（xfce4-session 启动后扫描 ~/.config/autostart；循环重启保常驻）──
    #    内容变更（wrapper 路径/参数变化）→ 重启 kasmvnc.service 让新会话拉起（session 启动时已扫过 autostart）
    mkdir -p /root/.config/autostart
    tmp=$(mktemp)
    cat > "$tmp" <<EOF
    [Desktop Entry]
    Type=Application
    Name=Microsoft Edge
    Comment=Web Browser (remote debugging 9222)
    Exec=${edgeRun}/bin/edge-run
    X-GNOME-Autostart-enabled=true
    EOF
    if ! cmp -s "$tmp" /root/.config/autostart/edge.desktop; then
      cp "$tmp" /root/.config/autostart/edge.desktop
      # 会话已运行时 autostart 不会重扫 → 重启 kasmvnc.service（Xvnc -fg 模式，重启即新会话）
      /usr/bin/systemctl restart kasmvnc.service 2>/dev/null || echo "警告: kasmvnc.service 重启失败（edge autostart 变更）"
    fi
    rm -f "$tmp"

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
