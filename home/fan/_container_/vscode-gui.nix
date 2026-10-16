# vscode GUI 客户端（容器桌面会话用；ide-si 无桌面会话 → 门控跳过）
#   与 _container_/vscode-server.nix 互补不冲突：本模块是桌面会话里以 fan 跑的 GUI 客户端
#   （profile ~/.config/Code、扩展 ~/.vscode/extensions），后者是 remote-ssh 连入用的 server
#   （~/.vscode-server），二者目录不重叠。
#   不用 vscode.enable：容器 HM 家目录是 /root，而桌面会话以 fan 运行（HOME=/home/fan），
#   走该选项会落错家目录（桌面会话读不到）。
#   包走 pkgs.vscode（unfree，flake.nix 全局白名单已含 "vscode"）：x86_64 与 aarch64 通吃，无需架构分支。
# 坑（同 ide-*/chrome.nix 的容器 Electron/Chromium 先例）：
#   1) 容器 fan 无 user namespace → 必须 --no-sandbox
#   2) 容器 /dev/shm 仅 64M（Docker 默认）→ --disable-dev-shm-usage，否则渲染进程崩溃
#   3) 无 GPU 容器 GLX 缺失 → --disable-gpu（软渲染）
#   4) --user-data-dir 显式指到 fan 会话家目录：GUI 从 plank 启动时 cwd/PATH 不可控，
#      不指则默认落 $HOME/.config/Code —— 显式写出以免与 root 侧 /root/.config/Code 混淆
# 图标名 "vscode"：nixpkgs vscode 装 $out/share/icons/hicolor/<size>/apps/vscode.png
#   （desktop 项内 Icon=vscode），须让 Gtk.IconTheme 能按名解析 → 见下方 hicolor symlink。
{
  pkgs,
  lib,
  hostName,
  ...
}:
let
  # 桌面会话 home（KasmVNC 会话为 fan）：同 ide-*/chrome.nix 的显式常量
  sessionHome = "/home/fan";
  # 仅暴露带容器参数的入口：裸 code 在容器里缺 flag 会直接崩，且 profile 目录不一致
  codeWrapper = pkgs.writeShellScriptBin "code-gui" ''
    exec ${pkgs.vscode}/bin/code --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir=${sessionHome}/.config/Code "$@"
  '';
  # store 内桌面项：Plank 的 dockitem Launcher 指向它 → 路径永不缺失，不会被 Plank 自动删除
  codeDesktop = pkgs.makeDesktopItem {
    name = "code";
    desktopName = "Visual Studio Code";
    exec = "${codeWrapper}/bin/code-gui %U";
    icon = "vscode";
    terminal = false;
    categories = [
      "Development"
      "TextEditor"
      "IDE"
    ];
    startupWMClass = "Code";
  };
in
lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && hostName != "ide-si") {
  home.packages = [
    pkgs.vscode
    codeWrapper
  ];

  home.activation.vscodeDock = lib.hm.dag.entryAfter [ "kasmvncBeautify" ] ''
    # ── 1. 应用菜单项：symlink 到 store 桌面项（xfce whisker 菜单可见，与 dock 同源不漂移）──
    mkdir -p ${sessionHome}/.local/share/applications
    ln -sfn ${codeDesktop}/share/applications/code.desktop ${sessionHome}/.local/share/applications/code.desktop

    # ── 2. 图标：逐文件链入 user icons/hicolor，使图标名 vscode 可解析 ──
    #     hicolor 建成真目录而非整目录 symlink：ide-*/chrome.nix 往同一目录放自己的图标（两边同级 DAG），
    #     各自逐文件链入 → 互不覆盖，不依赖激活顺序
    #     SRC 存在性：nixpkgs vscode generic.nix:329-330 装 $out/share/icons/hicolor/$size/apps/vscode.png
    #       （iconName 默认 "vs" + executableName → "vscode"，:60；size 由 identify 动态取，故用循环遍历而非写死尺寸）
    dest=${sessionHome}/.local/share/icons/hicolor
    if [ -L "$dest" ]; then rm -f "$dest"; fi   # 旧世代遗留的整目录 symlink（幂等；须 if 形式，hm activate 是 set -eu）
    src=${pkgs.vscode}/share/icons/hicolor
    find "$src" -type f | while read -r iconFile; do
      rel="''${iconFile#$src/}"
      mkdir -p "$dest/$(dirname "$rel")"
      ln -sfn "$iconFile" "$dest/$rel"
    done

    # ── 3. Plank dock 固定 vscode：Launcher 指 store 内 .desktop（永不缺失 → 不被 Plank 自动删除）──
    #     顺序不作保证（不碰 dock1/settings，对 plank 0.11.89 是死配置）
    mkdir -p ${sessionHome}/.config/plank/dock1/launchers
    cat > ${sessionHome}/.config/plank/dock1/launchers/vscode.dockitem <<EOF
    [PlankDockItemPreferences]
    Launcher=file://${codeDesktop}/share/applications/code.desktop
    EOF
  '';
}
