# ide-lenovo 专属：KasmVNC 浏览器远程桌面（xfce4 桌面，无 GPU 软渲染）
# 访问：http://<lenovo-ip>:6901/vnc.html（compose 映射 6901:6901），用户名 root + 密码
# 密码：nix 管理（secrets/source/kasmvnc-passwd → encrypt.sh → .age，激活 age 解密写入）
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
  # ── 基础应用（xfce 捆绑全家桶，容器远程桌面日常所需）──
  thunar = pkgs.thunar; # 文件管理器（Failsafe 会话已引用 --daemon，此前未装导致目录打不开）
  xfce4-appfinder = pkgs.xfce4-appfinder; # 应用查找器（Alt+F2 / 菜单搜索）
  whiskermenu = pkgs.xfce4-whiskermenu-plugin; # 应用菜单（面板主菜单，替代默认 applicationsmenu）
  xfce4-notifyd = pkgs.xfce4-notifyd; # 通知守护（dbus 激活）
  xfce4-screenshooter = pkgs.xfce4-screenshooter; # 截图
  xfce4-taskmanager = pkgs.xfce4-taskmanager; # 任务管理器
  xfce4-clipman = pkgs.xfce4-clipman-plugin; # 剪贴板历史（面板插件）
  mousepad = pkgs.mousepad; # 文本编辑器
  xarchiver = pkgs.xarchiver; # 压缩包管理
  # ── 美化（WhiteSur macOS 风格，linux265 帖子方案：WhiteSur-Gtk-theme/icon/cursors + Plank dock）──
  whitesurGtk = pkgs.whitesur-gtk-theme.override { colorVariants = [ "dark" ]; }; # GTK2/3/4 + xfwm4 + plank 主题（只留 dark 减体积）
  whitesurIcon = pkgs.whitesur-icon-theme; # 图标（目录名 WhiteSur-dark，小写 d）
  whitesurCursors = pkgs.whitesur-cursors; # 鼠标（目录名 WhiteSur-cursors）
  plank = pkgs.plank; # macOS 风格 dock（底部，替代底部面板）
  albert = pkgs.albert; # 搜索（帖子第 4 步）
  notoCjk = pkgs.noto-fonts-cjk-sans; # 中文渲染（兜底）
  sarasa = pkgs.sarasa-gothic; # 更纱黑体（等宽+中文，界面主字体，用户选定）
  # fcitx5 中文输入法（参考 nix-pve i18n.inputMethod.fcitx5：全拼默认 + 云拼音/标点策略）
  fcitx5 = pkgs.qt6Packages.fcitx5-with-addons.override {
    addons = [ pkgs.kdePackages.fcitx5-chinese-addons ];
  };
  fcitx5-gtk = pkgs.fcitx5-gtk; # GTK IM module（GTK_IM_MODULE=fcitx 加载）
  fcitx5-qt = pkgs.qt6Packages.fcitx5-qt; # QT IM module（QT_IM_MODULE=fcitx 加载）
  imagemagick = pkgs.imagemagick; # 壁纸生成
  fontconfig = pkgs.fontconfig; # 字体配置（容器无 /etc/fonts，字体全不生效）
  glibc = pkgs.glibc; # localedef 生成 zh_CN.UTF-8（容器 /usr/share/i18n 被裁剪）
  # 主题名（WhiteSur：GTK WhiteSur-Dark、图标 WhiteSur-dark、光标 WhiteSur-cursors，nixpkgs 实证目录名）
  gtkTheme = "WhiteSur-Dark";
  iconTheme = "WhiteSur-dark";
  cursorTheme = "WhiteSur-cursors";
  # xstartup / systemd service 运行时 PATH：xfce 核心组件 + 基础应用 + dbus + xauth/xkbcomp（kasmvncserver wrap 已带，双保险）
  runPath = lib.makeBinPath [
    kasmvnc
    xfce4-session
    xfwm4
    xfce4-panel
    xfdesktop
    xfce4-settings
    xfce4-terminal
    xfconf
    thunar
    xfce4-appfinder
    whiskermenu
    xfce4-notifyd
    xfce4-screenshooter
    xfce4-taskmanager
    xfce4-clipman
    mousepad
    xarchiver
    plank
    albert
    fcitx5
    pkgs.dbus
    pkgs.xauth
    pkgs.xkbcomp
  ];
  # XDG_DATA_DIRS：GTK 主题/图标/翻译查找路径（容器无 /usr/share，须指 nix store 各包 share）
  # 面板插件查找也走 XDG_DATA_DIRS/xfce4/panel/plugins（缺则插件加载失败弹窗，如 clipman）
  xdgDataDirs = lib.concatStringsSep ":" [
    "${xfconf}/share"
    "${xfce4-session}/share"
    "${xfce4-panel}/share"
    "${xfdesktop}/share"
    "${xfce4-settings}/share"
    "${xfce4-terminal}/share"
    "${thunar}/share"
    "${whiskermenu}/share"
    "${xfce4-appfinder}/share"
    "${xfce4-notifyd}/share"
    "${xfce4-screenshooter}/share"
    "${xfce4-taskmanager}/share"
    "${xfce4-clipman}/share"
    "${whitesurGtk}/share"
    "${whitesurIcon}/share"
    "${whitesurCursors}/share"
    "${plank}/share"
    "${fcitx5}/share"
    "${pkgs.adwaita-icon-theme}/share"
  ];
in
# 仅 x86_64-linux（lenovo 真机架构）：deb 是 amd64，aarch64 上无法构建；
# homeConfigurations 默认 aarch64-linux（mac 上 eval 用），门控后不报平台错
lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  home.packages = with pkgs; [
    kasmvnc
    # xfce4 核心组件（GTK 软渲染稳定）
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
    # 基础应用（文件管理器/菜单/通知/截图/任务管理/剪贴板/编辑器/压缩包）
    thunar
    xfce4-appfinder
    whiskermenu
    xfce4-notifyd
    xfce4-screenshooter
    xfce4-taskmanager
    xfce4-clipman
    mousepad
    xarchiver
    # 美化：WhiteSur 主题/图标/鼠标 + Plank dock + Albert 搜索 + 中文字体/壁纸生成
    whitesurGtk
    whitesurIcon
    whitesurCursors
    plank
    albert
    notoCjk
    sarasa
    imagemagick
    # 中文输入法（fcitx5 + 拼音引擎 + GTK/QT IM module）
    fcitx5
    fcitx5-gtk
    fcitx5-qt
    # 系统支撑：fontconfig（/etc/fonts 缺失，字体全不生效）、glibc（localedef 生成中文 locale）
    fontconfig
    glibc
  ];

  # ── 美化声明式（WhiteSur macOS 风格）──
  # 核心坑：xfsettingsd 启动时总写默认（ThemeName=Adwaita）覆盖 xsettings 频道，且被杀后 xfce4-session 会重启它
  #   → 用户级 xfce4-session.xml 覆盖 Failsafe 会话（去掉 xfsettingsd）→ GTK 应用读 settings.ini（Catppuccin）
  #   已验证：xfsettingsd 不启动后 GTK 深色主题生效（截图亮度 58 vs Adwaita 200+）
  # 其余（xfwm4 窗口/壁纸/面板）走 xfconf 频道，xfsettingsd 不管，直接生效
  home.activation.kasmvncBeautify = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # 0. 主题/图标/鼠标 symlink 到传统路径（GTK 查找 ~/.themes ~/.icons，不依赖 XDG_DATA_DIRS 顺序）
    mkdir -p /root/.themes /root/.icons /root/.local/share/plank/themes
    ln -sfn ${whitesurGtk}/share/themes/${gtkTheme} /root/.themes/${gtkTheme}
    ln -sfn ${whitesurIcon}/share/icons/${iconTheme} /root/.icons/${iconTheme}
    ln -sfn ${whitesurCursors}/share/icons/${cursorTheme} /root/.icons/${cursorTheme}
    ln -sfn ${pkgs.adwaita-icon-theme}/share/icons/Adwaita /root/.icons/Adwaita
    ln -sfn ${pkgs.adwaita-icon-theme}/share/icons/hicolor /root/.icons/hicolor
    # Plank 主题：WhiteSur 的 dock.theme 在主题目录 plank/ 子目录 → symlink 到 plank 主题查找路径
    ln -sfn ${whitesurGtk}/share/themes/${gtkTheme}/plank /root/.local/share/plank/themes/${gtkTheme}

    # 0.5 壁纸源：仓库 assets/kde-wallpaper.jpg（声明式，容器重建不丢）
    mkdir -p /root/.config
    cp -f ${../../..}/assets/kde-wallpaper.jpg /root/.config/kde-wallpaper.jpg

    # 1. GTK 主题（xfsettingsd 不启动后 GTK 读 settings.ini；GTK2 读 ~/.gtkrc-2.0）
    mkdir -p /root/.config/gtk-3.0
    cat > /root/.config/gtk-3.0/settings.ini <<EOF
    [Settings]
    gtk-theme-name=${gtkTheme}
    gtk-icon-theme-name=${iconTheme}
    gtk-font-name=Sarasa Gothic SC 11
    gtk-cursor-theme-name=${cursorTheme}
    gtk-cursor-theme-size=24
    gtk-application-prefer-dark-theme=1
    gtk-xft-dpi=147456
    EOF
    cat > /root/.gtkrc-2.0 <<EOF
    gtk-theme-name = "${gtkTheme}"
    gtk-icon-theme-name = "${iconTheme}"
    gtk-font-name = "Sarasa Gothic SC 11"
    EOF

    # 2. xfce4-session Failsafe 会话（去掉 xfsettingsd——它写默认覆盖主题；键盘布局回默认，容器远程桌面无碍）
    mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-session" version="1.0">
      <property name="general" type="empty">
        <property name="FailsafeSessionName" type="string" value="Failsafe"/>
      </property>
      <property name="sessions" type="empty">
        <property name="Failsafe" type="empty">
          <property name="IsFailsafe" type="bool" value="true"/>
          <property name="Count" type="int" value="5"/>
          <property name="Client0_Command" type="array">
            <value type="string" value="xfwm4"/>
          </property>
          <property name="Client0_Priority" type="int" value="15"/>
          <property name="Client1_Command" type="array">
            <value type="string" value="xfce4-panel"/>
          </property>
          <property name="Client1_Priority" type="int" value="25"/>
          <property name="Client2_Command" type="array">
            <value type="string" value="Thunar"/>
            <value type="string" value="--daemon"/>
          </property>
          <property name="Client2_Priority" type="int" value="30"/>
          <property name="Client3_Command" type="array">
            <value type="string" value="xfdesktop"/>
          </property>
          <property name="Client3_Priority" type="int" value="35"/>
          <property name="Client4_Command" type="array">
            <value type="string" value="plank"/>
          </property>
          <property name="Client4_Priority" type="int" value="40"/>
        </property>
      </property>
    </channel>
    EOF

    # 2.5 HiDPI：Xft.dpi 144（1.5x 字体缩放，VNC 自适应分辨率下界面不溢出）
    #    xfsettingsd 不启动（写默认覆盖主题）→ xsettings 频道手动写文件（xfconfd 启动时读）
    #    GTK 应用读 xsettings 频道的 Xft/DPI（dbus 经 xfconfd）；gtk-xft-dpi 在 settings.ini（GTK3 直读）
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xsettings" version="1.0">
      <property name="Xft" type="empty">
        <property name="DPI" type="int" value="144"/>
      </property>
    </channel>
    EOF

    # 3. xfwm4 窗口装饰（WhiteSur 主题 + 右侧按钮）
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfwm4" version="1.0">
      <property name="general" type="empty">
        <property name="theme" type="string" value="${gtkTheme}"/>
        <property name="button_layout" type="string" value="O|HMC"/>
        <property name="title_font" type="string" value="Sarasa Gothic SC 10"/>
      </property>
    </channel>
    EOF

    # 4. 壁纸（xfdesktop 读 xfce4-desktop 频道；ImageMagick 生成 mocha 渐变 + 顶部色条）
    #    坑：xfdesktop 4.20 的 backdrop 属性路径用 RandR connector 名（xfw_monitor_get_connector），
    #    非 monitor0——Xvnc 的 connector 是 VNC-0（xdpyinfo/RandR 查询实证），写 monitor0 读不到 → 默认壁纸
    #    image-style=5 = XFCE_BACKDROP_IMAGE_ZOOMED（4.20 枚举：0 none/1 centered/2 tiled/3 stretched/4 scaled/5 zoomed/6 spanning）
    mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
    tmp_desktop=$(mktemp)
    cat > "$tmp_desktop" <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-desktop" version="1.0">
      <property name="backdrop" type="empty">
        <property name="screen0" type="empty">
          <property name="monitorVNC-0" type="empty">
            <property name="workspace0" type="empty">
              <property name="last-image" type="string" value="/root/.config/background.png"/>
              <property name="image-style" type="int" value="5"/>
            </property>
          </property>
        </property>
      </property>
    </channel>
    EOF
    desktop_changed=0
    # 语义检测（xfconfd 回写会加 last-settings-migration-version/改 XML 版本，cmp 恒不同 → 每次部署重启 VNC）
    if ! grep -q "monitorVNC-0" /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml 2>/dev/null \
      || ! grep -q "background.png" /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml 2>/dev/null; then
      cp "$tmp_desktop" /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
      desktop_changed=1
    fi
    rm -f "$tmp_desktop"

    # 5. 面板（单条顶部半透明 + 深色模式：whisker 菜单/任务列表/时钟/托盘/剪贴板）
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-panel" version="1.0">
      <property name="configver" type="int" value="2"/>
      <property name="panels" type="array">
        <value type="int" value="1"/>
        <property name="dark-mode" type="bool" value="true"/>
        <property name="panel-1" type="empty">
          <property name="position" type="string" value="p=11;x=0;y=0"/>
          <property name="length" type="uint" value="100"/>
          <property name="position-locked" type="bool" value="true"/>
          <property name="icon-size" type="uint" value="14"/>
          <property name="size" type="uint" value="20"/>
          <property name="background-alpha" type="uint" value="190"/>
          <property name="enable-struts" type="bool" value="true"/>
          <property name="plugin-ids" type="array">
            <value type="int" value="1"/>
            <value type="int" value="2"/>
            <value type="int" value="3"/>
            <value type="int" value="4"/>
            <value type="int" value="5"/>
            <value type="int" value="6"/>
          </property>
        </property>
      </property>
      <property name="plugins" type="empty">
        <property name="plugin-1" type="string" value="whiskermenu"/>
        <property name="plugin-2" type="string" value="tasklist">
          <property name="grouping" type="uint" value="1"/>
        </property>
        <property name="plugin-3" type="string" value="separator"/>
        <property name="plugin-4" type="string" value="clock">
          <property name="digital-format" type="string" value="%H:%M"/>
        </property>
        <property name="plugin-5" type="string" value="systray"/>
        <property name="plugin-6" type="string" value="clipman"/>
      </property>
    </channel>
    EOF

    # 面板配置推送：运行中的 panel 不重读 XML（xfconfd 未运行时文件修改无广播），
    # xfce4-session failsafe 也不重启 panel → 会话在跑则经 dbus 直推，panel 实时生效
    # 值须与上方 xfce4-panel.xml 的 size/icon-size 同步（改 XML 时一并改这里）
    if pgrep -f xfce4-session >/dev/null 2>&1; then
      sess_pid=$(pgrep -f xfce4-session | head -1)
      sess_dbus=$(tr '\0' '\n' < /proc/$sess_pid/environ 2>/dev/null | grep '^DBUS_SESSION_BUS_ADDRESS=' | cut -d= -f2-)
      sess_display=$(tr '\0' '\n' < /proc/$sess_pid/environ 2>/dev/null | grep '^DISPLAY=' | cut -d= -f2-)
      if [ -n "$sess_dbus" ] && [ -n "$sess_display" ]; then
        export DBUS_SESSION_BUS_ADDRESS="$sess_dbus" DISPLAY="$sess_display"
        # || true：会话刚启动 xfconfd 未就绪属预期（下次激活/会话重启自然生效）
        ${xfconf}/bin/xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 20 || true
        ${xfconf}/bin/xfconf-query -c xfce4-panel -p /panels/panel-1/icon-size -s 14 || true
      fi
    fi

    # fcitx5 中文输入法配置（参考 nix-pve i18n.inputMethod.fcitx5 settings：全拼默认 + 云拼音/标点策略）
    # profile 省略 Enabled Addons → fcitx5 启用全部可用 addons（pinyin 来自 fcitx5-chinese-addons）
    mkdir -p /root/.config/fcitx5/conf
    cat > /root/.config/fcitx5/profile <<EOF
    [Profile]
    Groups=Default
    Active Group=Default

    [Groups/0]
    Name=Default
    Default Layout=us
    DefaultIM=pinyin

    [Groups/0/Items/0]
    Name=keyboard-us
    Layout=

    [Groups/0/Items/1]
    Name=pinyin
    Layout=
    EOF
    cat > /root/.config/fcitx5/conf/pinyin.conf <<EOF
    [Global]
    FirstRun=False
    PageSize=9
    SpellEnabled=True
    SymbolsEnabled=True
    ChaiziEnabled=True
    CloudPinyinEnabled=True
    CloudPinyinIndex=2
    CloudPinyinAnimation=True
    EOF
    cat > /root/.config/fcitx5/conf/cloudpinyin.conf <<EOF
    [Global]
    MinimumPinyinLength=4
    Backend=Baidu
    Toggle Key=
    EOF
    cat > /root/.config/fcitx5/conf/punctuation.conf <<EOF
    [Global]
    Enabled=True
    HalfWidthPuncAfterLetterOrNumber=True
    TypePairedPunctuationsTogether=False
    EOF

    # 6. autostart 脚本（壁纸生成 + xfwm4/壁纸设置兜底；GTK 主题走 settings.ini 不需 xfconf）
    mkdir -p /root/.config/autostart
    # fcitx5 中文输入法（会话启动即拉起；配置见上方 fcitx5 配置段）
    cat > /root/.config/autostart/fcitx5.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Fcitx5
    Comment=Chinese Input Method
    Exec=${fcitx5}/bin/fcitx5
    X-GNOME-Autostart-enabled=true
    EOF
    cat > /root/.config/autostart/theme-setup.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Theme Setup
    Exec=/root/.config/autostart/theme-setup.sh
    X-GNOME-Autostart-enabled=true
    EOF
    cat > /root/.config/autostart/theme-setup.sh <<EOF
    #!/bin/sh
    # Catppuccin Mocha 壁纸/窗口设置（xfce4-session autostart 阶段执行，环境继承会话）
    # 时序坑：xfdesktop 启动可能早于 xfconfd 就绪（读到空值→默认壁纸），故 sleep 后设置并二次兑底
    sleep 3
    # 壁纸：kde-wallpaper.jpg（激活时从仓库 assets/ 复制）→ 横屏 1920x1080 macOS 风格（模糊填充 + 居中裁切）
    # 坑：composite 输出尺寸 = 较大输入，须用 \(...\) 子图像 + -extent 强制 1920x1080（否则输出源图尺寸 3350x1920）
    # 旧竖屏版（1080x1920）存在时删除重生成（分辨率变更迁移）
    # 坑：identify 失败时 bg_size 未赋值 → 激活 set -u 中止（unbound variable）→ 须 || echo 兑底
    if [ -f /root/.config/background.png ] && [ "$(${imagemagick}/bin/identify -format '%wx%h' /root/.config/background.png 2>/dev/null || echo x)" != "1920x1080" ]; then
      rm -f /root/.config/background.png
    fi
    if [ ! -f /root/.config/background.png ]; then
      ${imagemagick}/bin/magick /root/.config/kde-wallpaper.jpg -resize 1920x1080! -blur 0x30 /tmp/bg-blur.png 2>/dev/null \
        && ${imagemagick}/bin/magick /tmp/bg-blur.png \( /root/.config/kde-wallpaper.jpg -resize 1920x1080^ -gravity center -extent 1920x1080 \) -gravity center -composite /root/.config/background.png 2>/dev/null \
        && rm -f /tmp/bg-blur.png \
        || echo "警告: 壁纸生成失败"
    fi
    # 窗口装饰/壁纸（xfsettingsd 不管这些频道，设置即生效；xfdesktop 监听变更自动重载）
    # 路径用 monitorVNC-0（RandR connector 名，见上注释；monitor0 读不到）
    ${xfconf}/bin/xfconf-query -c xfwm4 -p /general/theme -s '${gtkTheme}'
    ${xfconf}/bin/xfconf-query -c xfce4-desktop --create -p /backdrop/screen0/monitorVNC-0/workspace0/last-image -s /root/.config/background.png
    ${xfconf}/bin/xfconf-query -c xfce4-desktop --create -p /backdrop/screen0/monitorVNC-0/workspace0/image-style -s 5
    sleep 2
    # 二次兑底：首次设置时 xfconfd 可能未就绪（PropertyNotFound），重设确保生效
    ${xfconf}/bin/xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVNC-0/workspace0/last-image -s /root/.config/background.png 2>/dev/null || true
    # xfdesktop 4.20 只监听启动时读过的属性路径（monitorVNC-0），设置后不重载 → 重启 xfdesktop 生效
    # （xfce4-session 的 failsafe 客户端监控不重启 xfdesktop，须手动拉起；SESSION_MANAGER 缺失仅告警不影响）
    pkill -f '[x]fdesktop' 2>/dev/null || true
    sleep 1
    xfdesktop &
    # Plank dock 配置（macOS 风格：底部居中、图标缩放、WhiteSur 主题）
    # 注意：plank 由 Failsafe 会话拉起（Client4=plank，环境含 XAUTHORITY），此处只写配置不碰进程
    #   （手动 pkill+plank & 会因缺 XAUTHORITY 报 'Only X11 environments are supported' 退出）
    mkdir -p /root/.config/plank/dock1
    cat > /root/.config/plank/dock1/settings <<'PLANKEOF'
    [PlankDockPreferences]
    position=bottom
    alignment=center
    icon-size=56
    zoom-enabled=true
    zoom-percent=150
    theme=WhiteSur-Dark
    hide-mode=none
    PLANKEOF
    # Plank 固定应用（dock 默认只显示运行中窗口——edge 未开时 dock 空/残桩；固定常用应用才有 macOS dock 观感）
    # dockitem 格式：[PlankDockItemPreferences] Launcher=file://<store>/share/applications/<name>.desktop
    # plank 用 GFileMonitor 监听 launchers 目录，写入后自动刷新（无需重启进程）
    mkdir -p /root/.config/plank/dock1/launchers
    cat > /root/.config/plank/dock1/launchers/edge.dockitem <<'DOCKEOF'
    [PlankDockItemPreferences]
    Launcher=file:///root/.local/share/applications/microsoft-edge.desktop
    DOCKEOF
    cat > /root/.config/plank/dock1/launchers/thunar.dockitem <<'DOCKEOF'
    [PlankDockItemPreferences]
    Launcher=file://${thunar}/share/applications/thunar.desktop
    DOCKEOF
    cat > /root/.config/plank/dock1/launchers/terminal.dockitem <<'DOCKEOF'
    [PlankDockItemPreferences]
    Launcher=file://${xfce4-terminal}/share/applications/xfce4-terminal.desktop
    DOCKEOF
    cat > /root/.config/plank/dock1/launchers/mousepad.dockitem <<'DOCKEOF'
    [PlankDockItemPreferences]
    Launcher=file://${mousepad}/share/applications/org.xfce.mousepad.desktop
    DOCKEOF
    cat > /root/.config/plank/dock1/launchers/settings.dockitem <<'DOCKEOF'
    [PlankDockItemPreferences]
    Launcher=file://${xfce4-settings}/share/applications/xfce-settings-manager.desktop
    DOCKEOF
    cat > /root/.config/plank/dock1/launchers/appfinder.dockitem <<'DOCKEOF'
    [PlankDockItemPreferences]
    Launcher=file://${xfce4-appfinder}/share/applications/xfce4-appfinder.desktop
    DOCKEOF
    EOF
    chmod +x /root/.config/autostart/theme-setup.sh

    # 6.5 外部面板插件 .desktop+.so 同目录 symlink（XDG_DATA_HOME 优先于 XDG_DATA_DIRS）
    #    坑1：nix 包布局 .desktop 在 share/、.so 在 lib/，xfce4-panel 按 .desktop 目录找 .so 会失败（弹'无法加载插件'）
    #    坑2：xfce4-panel 的模块表 key = .desktop 文件名（去 .desktop）——配置名 'clipman' 须有 clipman.desktop
    #        （包内文件名是 xfce4-clipman-plugin.desktop → key=xfce4-clipman-plugin，与配置名不匹配 → 弹窗）
    #    坑3：user datadir（/root/.local/share）的 libdir 配对是 /root/.local/lib/xfce4/panel/plugins——.so 须放那
    #    坑4：nix run 的 flake 求值 GC 可能删旧 store 路径（broken symlink），激活每次重写 symlink 指向当前路径
    mkdir -p /root/.local/share/xfce4/panel/plugins /root/.local/lib/xfce4/panel/plugins
    # whiskermenu：文件名即配置名，symlink 即可
    ln -sfn ${whiskermenu}/share/xfce4/panel/plugins/whiskermenu.desktop /root/.local/share/xfce4/panel/plugins/
    ln -sfn ${whiskermenu}/lib/xfce4/panel/plugins/libwhiskermenu.so /root/.local/share/xfce4/panel/plugins/
    ln -sfn ${whiskermenu}/lib/xfce4/panel/plugins/libwhiskermenu.so /root/.local/lib/xfce4/panel/plugins/
    # clipman：包内 .desktop 文件名（xfce4-clipman-plugin.desktop）≠ 配置名（clipman）→ 复制改名
    cp -f ${xfce4-clipman}/share/xfce4/panel/plugins/xfce4-clipman-plugin.desktop /root/.local/share/xfce4/panel/plugins/clipman.desktop
    ln -sfn ${xfce4-clipman}/lib/xfce4/panel/plugins/libclipman.so /root/.local/share/xfce4/panel/plugins/
    ln -sfn ${xfce4-clipman}/lib/xfce4/panel/plugins/libclipman.so /root/.local/lib/xfce4/panel/plugins/

    # 7. fontconfig：容器无 /etc/fonts（字体全不生效，中文方块/edge 字体报错）
    #    fonts.conf 用 nix fontconfig 包自带模板（含 conf.d include），再补 30-nix-fonts.conf 指 store 字体目录
    #    注意：fontconfig 默认输出是 bin（fc-* 命令），fonts.conf 在 out 输出 → 显式 .out
    mkdir -p /etc/fonts/conf.d
    cp -f ${fontconfig.out}/etc/fonts/fonts.conf /etc/fonts/fonts.conf
    cat > /etc/fonts/conf.d/30-nix-fonts.conf <<EOF
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <dir>${pkgs.dejavu_fonts}/share/fonts/truetype</dir>
      <dir>${notoCjk}/share/fonts/opentype/noto-cjk</dir>
      <dir>${sarasa}/share/fonts/truetype</dir>
      <dir prefix="xdg">fonts</dir>
    </fontconfig>
    EOF
    ${fontconfig.bin}/bin/fc-cache -f >/dev/null 2>&1 || echo "警告: fc-cache 失败（字体缓存未建）"

    # 8. locale：容器 /usr/share/i18n 被裁剪（无 locale-gen 源），用 nix glibc 的 localedef 生成到 /root/.locale
    #    xstartup export LOCPATH 指过去；--no-archive 目录形式，不污染系统 locale-archive
    #    注意：localedef 在 glibc 的 bin 输出（${glibc}/bin 主输出无），i18n 源数据在主输出
    mkdir -p /root/.locale
    export I18NPATH=${glibc}/share/i18n
    if [ ! -d /root/.locale/zh_CN.UTF-8 ]; then
      ${glibc.bin}/bin/localedef --no-archive -i zh_CN -f UTF-8 /root/.locale/zh_CN.UTF-8 || echo "警告: zh_CN.UTF-8 locale 生成失败"
    fi
    if [ ! -d /root/.locale/en_US.UTF-8 ]; then
      ${glibc.bin}/bin/localedef --no-archive -i en_US -f UTF-8 /root/.locale/en_US.UTF-8 || echo "警告: en_US.UTF-8 locale 生成失败"
    fi

    # 9. nix.conf 防 GC：nix run 的 flake 求值 GC 曾删掉被 profile 引用的插件 store 路径（broken symlink）
    #    gc-keep-outputs/derivations 保留 live 输出的 .drv 与输出（幂等追加，容器重建后自动恢复）
    if ! grep -q "gc-keep-outputs" /etc/nix/nix.conf 2>/dev/null; then
      echo "gc-keep-outputs = true" >> /etc/nix/nix.conf
      echo "gc-keep-derivations = true" >> /etc/nix/nix.conf
    fi

    # 10. xfce4-desktop.xml 变更（壁纸路径/样式）→ 运行中 xfdesktop 不重载（4.20 只监听启动时读过的属性路径）
    #     重启 kasmvnc.service 让新会话生效（VNC 客户端重连即可；theme-setup.sh 的 pkill 自愈覆盖会话内变更）
    if [ "$desktop_changed" = "1" ] && /usr/bin/systemctl is-active --quiet kasmvnc.service 2>/dev/null; then
      echo "===> xfce4-desktop.xml 已变更，重启 kasmvnc.service 让新会话生效"
      /usr/bin/systemctl restart kasmvnc.service 2>/dev/null || echo "警告: kasmvnc.service 重启失败（壁纸变更）"
    fi
  '';

  home.activation.kasmvnc = lib.hm.dag.entryAfter [ "edge" ] ''
    # ── 0. Xvnc 硬编码系统路径（ELF 内嵌，无法 sed/wrap）：
    #    /usr/share/X11/xkb（xkb 数据）与 /usr/bin/xkbcomp（keymap 编译器）
    #    nix 的 xkeyboard_config/xkbcomp 在 store，容器无此路径 → symlink 指 store（幂等）
    mkdir -p /usr/share/X11
    ln -sfn ${pkgs.xkeyboard_config}/share/X11/xkb /usr/share/X11/xkb
    ln -sfn ${pkgs.xkbcomp}/bin/xkbcomp /usr/bin/xkbcomp

    # ── 1. 会话启动脚本（xfce4-session + dbus；store 绝对路径，不依赖 HM profile PATH）──
    # dbus：不用 dbus-launch（nix 编译期硬编码 /run/current-system/sw/bin/dbus-daemon，容器无此路径）
    #   → dbus-daemon 直起，--config-file 显式指 nix store 的 session.conf；
    #   坑：不能带 --session（隐含默认 /etc/dbus-1/session.conf，与 --config-file 冲突报错）
    # 变更检测：xstartup 内容变更 → 重启 service（新会话才读新 xstartup）
    mkdir -p /root/.vnc
    tmp_xstartup=$(mktemp)
    cat > "$tmp_xstartup" <<EOF
    #!/bin/sh
    # KasmVNC 会话启动（激活生成，声明式；改配置在 home/fan/ide-lenovo/kasmvnc.nix）
    unset SESSION_MANAGER
    unset DBUS_SESSION_BUS_ADDRESS
    export PATH="${runPath}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    # 中文 locale（激活时 localedef 生成到 /root/.locale；容器系统 locale 只有 C.UTF-8）
    export LOCPATH=/root/.locale
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
    # fcitx5 中文输入法：GTK/QT IM module + XIM；GTK_PATH 指 fcitx5-gtk immodule（GTK 默认路径找不到）
    export GTK_IM_MODULE=fcitx
    export QT_IM_MODULE=fcitx
    export XMODIFIERS=@im=fcitx
    export GTK_PATH="${fcitx5-gtk}/lib/gtk-3.0"
    export QT_PLUGIN_PATH="${fcitx5-qt}/lib/qt5/plugins:${fcitx5-qt}/lib/qt6/plugins"
    # xfconfd 靠 dbus 激活（org.xfce.Xfconf.service 在 xfconf 包 share/dbus-1/services），
    # dbus 标准目录找不到 store 路径 → XDG_DATA_DIRS 指 xfconf share（standard_session_servicedirs 读它）
    # 同时指各包 share：GTK 主题/图标/翻译查找（容器无 /usr/share）
    export XDG_DATA_DIRS="${xdgDataDirs}"
    # xfconfd 读配置用 XDG_CONFIG_DIRS（默认 /etc/xdg，容器无 nix 配置）→ 指 xfce4-session 的 etc/xdg
    # （xfce4-session.xml 的 Failsafe 会话定义；缺则 xfconfd 报 PropertyNotFound →
    #   xfsm_manager_load_failsafe 失败 → 弹模态错误对话框阻塞启动）
    export XDG_CONFIG_DIRS="${xfce4-session}/etc/xdg:/etc/xdg"
    # XDG_CURRENT_DESKTOP：plank 等应用检测桌面环境（缺则报 'Only X11 environments are supported'）
    export XDG_CURRENT_DESKTOP=XFCE
    export XDG_SESSION_DESKTOP=xfce
    export DBUS_SESSION_BUS_ADDRESS=\$(${pkgs.dbus}/bin/dbus-daemon --fork --print-address --config-file=${pkgs.dbus}/share/dbus-1/session.conf)
    exec ${xfce4-session}/bin/xfce4-session
    EOF
    chmod +x "$tmp_xstartup"
    xstartup_changed=0
    if ! cmp -s "$tmp_xstartup" /root/.vnc/xstartup; then
      cp "$tmp_xstartup" /root/.vnc/xstartup
      xstartup_changed=1
    fi
    rm -f "$tmp_xstartup"

    # ── 2. 用户级配置（覆盖 defaults：分辨率/端口/httpd_directory/字体/SSL）──
    # defaults 的 ssl 指 Debian snakeoil（容器无），须生成自签名证书并覆盖；require_ssl: false（http 访问）
    if [ ! -f /root/.vnc/kasmvnc-cert.pem ]; then
      ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout /root/.vnc/kasmvnc-key.pem -out /root/.vnc/kasmvnc-cert.pem \
        -days 3650 -subj "/CN=lenovo-ide" 2>/dev/null
    fi
    cat > /root/.vnc/kasmvnc.yaml <<EOF
    desktop:
      resolution:
        width: 1920
        height: 1080
      # 自适应：客户端连接/窗口变化时服务器分辨率跟随（Remote Resizing）
      # 坑：分辨率变化后面板可能不跟随（length 百分比失效）→ 见 kasmvncBeautify 面板段注释
      allow_resize: true
    network:
      protocol: http
      websocket_port: 6901
      ssl:
        pem_certificate: /root/.vnc/kasmvnc-cert.pem
        pem_key: /root/.vnc/kasmvnc-key.pem
        require_ssl: false
    server:
      http:
        httpd_directory: ${kasmvnc}/share/kasmvnc/www
      advanced:
        x_font_path: ${pkgs.dejavu_fonts}/share/fonts/truetype
    EOF

    # ── 3. 密码：age 解密（secrets/source/hosts/ide-lenovo/kasmvnc-passwd → encrypt.sh 生成 .age，git 可公开）──
    #    私钥 $HOME/.secrets/age-keys.txt（compose 挂载，容器重建不丢）；解密失败即部署失败
    #    hash 标记比较，密码变更才重写（声明式收敛：手改密码下次激活回滚；无变更不打扰运行中会话）
    pass_file=/root/.kasmpasswd
    pass_hash=/root/.vnc/kasmvnc-passwd.sha256
    tmp=$(mktemp)
    ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" -o "$tmp" ${../../..}/secrets/hosts/ide-lenovo/kasmvnc-passwd.age
    new_hash=$(${pkgs.coreutils}/bin/sha256sum "$tmp" | cut -d' ' -f1)
    if [ ! -f "$pass_hash" ] || [ "$(cat "$pass_hash" 2>/dev/null)" != "$new_hash" ]; then
      printf '%s\n%s\n' "$(cat "$tmp")" "$(cat "$tmp")" | ${kasmvnc}/bin/kasmvncpasswd -u root -w
      echo "$new_hash" > "$pass_hash"
      echo "===> kasmvnc 密码已更新（nix 管理，secrets/source/kasmvnc-passwd）"
    fi
    rm -f "$tmp"

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
    # 重启条件：unit 变更（kasmvnc 升级，旧进程仍跑旧二进制）、xstartup 变更（新会话配置）或服务未存活（崩溃循环）
    state=$(/usr/bin/systemctl show -p ActiveState --value kasmvnc.service 2>/dev/null || echo unknown)
    if [ "$unit_changed" = "1" ] || [ "$xstartup_changed" = "1" ] || [ "$state" != "active" ]; then
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
