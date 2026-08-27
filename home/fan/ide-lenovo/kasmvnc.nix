# ide-lenovo 专属：KasmVNC 浏览器远程桌面（xfce4 桌面，无 GPU 软渲染）
# 访问：http://<lenovo-ip>:6901/vnc.html（compose 映射 6901:6901），用户名 root + 密码
# 密码：首次激活生成随机密码（/root/.kasmpasswd），部署日志打印；改密码 docker exec ide kasmvncpasswd -u root -w
# 包：packages/kasmvnc.nix（官方 deb 解包自打包，nixpkgs 无此包）
# 桌面：xfce4（GTK 软渲染稳定，KasmVNC 官方默认；KDE 黑屏坑多已弃）
# 会话：~/.vnc/xstartup 激活生成（dbus-launch + xfce4-session，store 绝对路径 + PATH 注入）
# 配置：~/.vnc/kasmvnc.yaml 激活生成（覆盖 defaults：分辨率/端口/httpd_directory/字体）

{ pkgs, lib, ... }:
let
  kasmvnc = pkgs.kasmvnc;
  # 26.05 起 xfce 组件移顶层（pkgs.xfce4-session 等，xfce.* 已 deprecated）
  xfce4-session = pkgs.xfce4-session;
  xfwm4 = pkgs.xfwm4;
  xfce4-panel = pkgs.xfce4-panel;
  xfdesktop = pkgs.xfdesktop;
  xfce4-settings = pkgs.xfce4-settings;
  xfce4-terminal = pkgs.xfce4-terminal;
  xfconf = pkgs.xfconf;
  # xstartup / systemd service 运行时 PATH：xfce 核心组件 + dbus + xauth/xkbcomp（kasmvncserver wrap 已带，双保险）
  # 最小集：session/wm/panel/desktop/settings/xfconf/terminal，其余 xfce 捆绑（appfinder/screenshooter/taskmanager/whisker/clipman/notifyd/thunar）不装
  runPath = lib.makeBinPath [
    kasmvnc
    xfce4-session
    xfwm4
    xfce4-panel
    xfdesktop
    xfce4-settings
    xfce4-terminal
    xfconf
    pkgs.dbus
    pkgs.xauth
    pkgs.xkbcomp
  ];
in
# 仅 x86_64-linux（lenovo 真机架构）：deb 是 amd64，aarch64 上无法构建；
# homeConfigurations 默认 aarch64-linux（mac 上 eval 用），门控后不报平台错
lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  home.packages = with pkgs; [
    kasmvnc
    # xfce4 核心组件（GTK 软渲染稳定；最小集，不装捆绑应用）
    xfce4-session
    xfwm4
    xfce4-panel
    xfdesktop
    xfce4-settings
    xfce4-terminal
    xfconf
    dbus
    adwaita-icon-theme # GTK 默认图标（无则界面空白）
    dejavu_fonts # Xvnc 渲染 + 界面字体
  ];

  home.activation.kasmvnc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # ── 1. 会话启动脚本（xfce4-session + dbus；store 绝对路径，不依赖 HM profile PATH）──
    mkdir -p /root/.vnc
    cat > /root/.vnc/xstartup <<EOF
    #!/bin/sh
    # KasmVNC 会话启动（激活生成，声明式；改配置在 home/fan/ide-lenovo/kasmvnc.nix）
    unset SESSION_MANAGER
    unset DBUS_SESSION_BUS_ADDRESS
    export PATH="${runPath}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    exec ${pkgs.dbus}/bin/dbus-launch --exit-with-session ${xfce4-session}/bin/xfce4-session
    EOF
    chmod +x /root/.vnc/xstartup

    # ── 2. 用户级配置（覆盖 defaults：分辨率/端口/httpd_directory/字体）──
    cat > /root/.vnc/kasmvnc.yaml <<EOF
    desktop:
      resolution:
        width: 1920
        height: 1080
      allow_resize: true
    network:
      protocol: http
      websocket_port: 6901
    server:
      http:
        httpd_directory: ${kasmvnc}/share/kasmvnc/www
      advanced:
        x_font_path: ${pkgs.dejavu_fonts}/share/fonts/truetype
    EOF

    # ── 3. 密码：首次生成随机密码（已存在不覆盖，用户改过密码保留）──
    if [ ! -s /root/.kasmpasswd ]; then
      pass=$(head -c 12 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 12)
      printf '%s\n%s\n' "$pass" "$pass" | ${kasmvnc}/bin/kasmvncpasswd -u root -w
      echo "===> kasmvnc 初始密码: $pass"
      echo "===> 浏览器访问 http://<lenovo-ip>:6901/vnc.html，用户名 root"
      echo "===> 改密码: docker exec ide kasmvncpasswd -u root -w"
    fi

    # ── 4. systemd service（幂等写入 + 变更重启，同 skemate 模式）──
    unit=/etc/systemd/system/kasmvnc.service
    tmp=$(mktemp)
    sed -e "s|@kasmvnc@|${kasmvnc}|" -e "s|@path@|${runPath}|" ${./kasmvnc.service} > "$tmp"
    unit_changed=0
    if ! cmp -s "$tmp" "$unit"; then
      cp "$tmp" "$unit"
      unit_changed=1
    fi
    rm -f "$tmp"
    if ! /usr/bin/systemctl daemon-reload; then
      echo "警告: systemctl daemon-reload 失败，错误如上"
    fi
    if ! /usr/bin/systemctl enable kasmvnc.service; then
      echo "警告: systemctl enable kasmvnc.service 失败，错误如上（容器重启后不会自启）"
    fi
    # 重启条件：unit 变更（kasmvnc 升级，旧进程仍跑旧二进制）或服务未存活（崩溃循环）
    state=$(/usr/bin/systemctl show -p ActiveState --value kasmvnc.service 2>/dev/null || echo unknown)
    if [ "$unit_changed" = "1" ] || [ "$state" != "active" ]; then
      if /usr/bin/systemctl restart kasmvnc.service; then
        sleep 2
        state=$(/usr/bin/systemctl show -p ActiveState --value kasmvnc.service 2>/dev/null || echo unknown)
        if [ "$state" = "active" ]; then
          echo "===> kasmvnc.service 已重新拉起"
        else
          echo "警告: kasmvnc.service 拉起后未存活（当前状态 $state ，可能崩溃循环），最近日志："
          /usr/bin/journalctl -u kasmvnc.service -n 10 --no-pager 2>/dev/null || true
        fi
      else
        echo "警告: systemctl restart kasmvnc.service 失败（错误如上），unit 状态："
        /usr/bin/systemctl status kasmvnc.service --no-pager -n 5 2>&1 | head -12 || true
        /usr/bin/journalctl -u kasmvnc.service -n 10 --no-pager 2>/dev/null || true
      fi
    fi
  '';
}
