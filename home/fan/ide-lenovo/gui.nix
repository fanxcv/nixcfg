# ide-lenovo GUI：KDE Plasma 6（X11 会话）+ xrdp 远程桌面（RDP 协议）
# 架构：纯 Nix，镜像零改动；容器 PID1 即 systemd，xrdp/dbus 服务照 _container_/skemate.nix 模式
#       （activation 幂等写 /etc/systemd/system + systemctl enable/restart）
# 远程：宿主 compose 映射 13389:3389；root 登录（密码取 /root/.secrets/xrdp-password，缺失则空密码 nullok）
# 渲染：llvmpipe 软渲染（无 GPU）；中文：plasma-localerc zh_CN + fcitx5 拼音 + Noto CJK
# 参考：_nixos_/gui/plasma.nix（主题/面板/中文）+ nixpkgs services.xrdp 模块（配置模板替换）
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Catppuccin latte 壁纸（nixpkgs 的 nixos-artwork 自带，路径同 _nixos_/gui/plasma.nix）
  wallpaper = "${
    pkgs.nixos-artwork.wallpapers."catppuccin-latte"
  }/share/backgrounds/nixos/nixos-wallpaper-catppuccin-latte.png";
in
{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  home.packages = [
    # KDE Plasma 6 桌面（plasma-workspace 提供 startplasma-x11 会话脚本）
    pkgs.kdePackages.plasma-desktop
    pkgs.kdePackages.plasma-workspace
    pkgs.kdePackages.konsole
    pkgs.kdePackages.dolphin
    pkgs.kdePackages.systemsettings
    pkgs.kdePackages.kate
    pkgs.kdePackages.ark
    # 远程桌面：xrdp（RDP 服务，包自带 /etc/xrdp 配置模板与 Xorg 会话段）
    # + xorg-server（Xorg 二进制，sesman.ini 里绝对路径引用）+ xorgxrdp（xrdp 包 passthru，
    #   不在 xrdp 闭包，须显式入 profile 防 GC）
    pkgs.xrdp
    pkgs.xrdp.passthru.xorgxrdp
    pkgs.xorg-server
    # 系统 dbus：KDE 强依赖，容器镜像未装；nix 包自带系统/用户级 systemd units，activation 链接启用
    pkgs.dbus
    # 中文：Noto CJK 字体（容器无 fontconfig 系统层，直接装包 + plasma 字体写死；26.05 拆为 sans/serif）
    pkgs.noto-fonts-cjk-sans
    # 主题：Catppuccin latte + Papirus 亮色图标 + Konsole mocha 配色（本地包）
    (pkgs.catppuccin-kde.override {
      flavour = [ "latte" ];
      accents = [ "blue" ];
    })
    pkgs.papirus-icon-theme
    pkgs.catppuccin-konsole
  ];

  programs.plasma = {
    enable = true;

    # 主题：Catppuccin Latte 配色/开机画面 + Papirus 亮色图标 + 桌面壁纸
    workspace = {
      colorScheme = "CatppuccinLatteBlue";
      splashScreen.theme = "Catppuccin-Latte-Blue";
      cursor.theme = "Breeze_Light";
      iconTheme = "Papirus";
      inherit wallpaper;
    };

    # 锁屏壁纸（与桌面同款）
    kscreenlocker.appearance = { inherit wallpaper; };

    # 字体：Noto CJK（容器无 fontconfig defaultFonts，写死；与 _nixos_ 的 Noto CJK 策略一致）
    fonts = {
      general = {
        family = "Noto Sans CJK SC";
        pointSize = 10;
      };
      fixedWidth = {
        family = "Noto Sans Mono CJK SC";
        pointSize = 10;
      };
      menu = {
        family = "Noto Sans CJK SC";
        pointSize = 10;
      };
      small = {
        family = "Noto Sans CJK SC";
        pointSize = 8;
      };
      windowTitle = {
        family = "Noto Sans CJK SC";
        pointSize = 10;
      };
      toolbar = {
        family = "Noto Sans CJK SC";
        pointSize = 10;
      };
    };

    # 底部浮动面板：启动器 + 任务栏 + 托盘 + 时钟（同 _nixos_/gui/plasma.nix）
    panels = [
      {
        alignment = "center";
        floating = true;
        height = 36;
        hiding = "none";
        lengthMode = "fill";
        location = "bottom";
        opacity = "adaptive";
        widgets = [
          {
            name = "org.kde.plasma.kickoff";
            config = {
              popupHeight = 650;
              popupWidth = 750;
              General = {
                alphaSort = true;
                icon = "distributor-logo-nixos";
                showRecentApps = false;
                showRecentDocs = false;
                systemFavorites = "suspend\\,reboot\\,shutdown";
              };
            };
          }
          {
            name = "org.kde.plasma.pager";
          }
          {
            name = "org.kde.plasma.icontasks";
          }
          {
            name = "org.kde.plasma.systemtray";
          }
          {
            name = "org.kde.plasma.digitalclock";
          }
        ];
      }
    ];

    # KWin：4 虚拟桌面（2x2）+ 窗口贴边吸附
    configFile.kwinrc = {
      Desktops = {
        Number = 4;
        Rows = 2;
      };
      Windows = {
        RollOverDesktops = true;
        BorderSnapZone = 10;
        WindowSnapZone = 10;
      };
    };

    # 会话：空会话启动（不恢复上次桌面）
    configFile.ksmserverrc.General = {
      loginMode = "emptySession";
    };

    # 界面中文：写 ~/.config/plasma-localerc，只影响 KDE 界面；终端/SSH 环境保持 en_US
    configFile."plasma-localerc" = {
      Translations = {
        Language = "zh_CN";
      };
    };

    # 禁用 KWallet：root 会话避免凭据弹窗卡住 RDP 登录（krdp 的 KWallet 坑同理规避）
    configFile.kwalletrc = {
      Wallet = {
        Enabled = false;
      };
    };

    # 禁用 baloo 文件索引：容器挂载大目录（nixcfg 等），索引持续吃 CPU 与宿主磁盘，无搜索需求
    configFile.baloorc = {
      "Basic Settings" = {
        "Indexing-Enabled" = false;
      };
    };
  };

  # Konsole 终端：catppuccin mocha 配色（配色文件自打包，软链到 ~/.local/share/konsole/）
  home.file.".local/share/konsole/catppuccin-mocha.colorscheme".source =
    "${pkgs.catppuccin-konsole}/catppuccin-mocha.colorscheme";

  programs.konsole = {
    enable = true;
    ui.colorScheme = "BreezeDark";
    profiles.Default = {
      colorScheme = "catppuccin-mocha";
      font = {
        name = "Noto Sans Mono CJK SC";
        size = 11;
      };
    };
  };

  # fcitx5 中文输入法（拼音默认；X11 会话，无 Wayland 虚拟键盘联动）
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = [
        pkgs.kdePackages.fcitx5-chinese-addons
      ];
      settings = {
        inputMethod = {
          "GroupOrder"."0" = "Default";
          "Groups/0" = {
            "Name" = "Default";
            "Default Layout" = "us";
            "DefaultIM" = "pinyin";
          };
          "Groups/0/Items/0"."Name" = "keyboard-us";
          "Groups/0/Items/1"."Name" = "pinyin";
        };
        addons = {
          pinyin.globalSection = {
            "FirstRun" = "False";
            "PageSize" = 9;
            "SpellEnabled" = "True";
            "SymbolsEnabled" = "True";
            "CloudPinyinEnabled" = "True";
            "CloudPinyinIndex" = 2;
          };
          cloudpinyin.globalSection = {
            "MinimumPinyinLength" = 4;
            "Backend" = "Baidu";
          };
        };
      };
    };
  };

  # xrdp + dbus 系统服务：配置模板/证书/pam/units 全由 activation 幂等落盘（照 _container_/skemate.nix 模式）
  home.activation.xrdpGui = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # --- 1. xrdp 配置目录（模板来自 xrdp 包自带 /etc/xrdp，含 xrdp.ini/sesman.ini/startwm.sh）---
    mkdir -p /etc/xrdp
    cp -r ${pkgs.xrdp}/etc/xrdp/. /etc/xrdp/
    # 关键项替换（照 nixpkgs services.xrdp 模块）：rsakeys 路径、日志走 journal、startwm 绝对路径
    sed -i 's|#rsakeys_ini=|rsakeys_ini=/run/xrdp/rsakeys.ini|' /etc/xrdp/xrdp.ini
    sed -i 's|LogFile=xrdp.log|LogFile=/dev/null|; s|EnableSyslog=true|EnableSyslog=false|' /etc/xrdp/xrdp.ini
    sed -i 's|LogFile=xrdp-sesman.log|LogFile=/dev/null|; s|EnableSyslog=true|EnableSyslog=false|' /etc/xrdp/sesman.ini
    sed -i 's|startwm.sh|/etc/xrdp/startwm.sh|g; s|reconnectwm.sh|/etc/xrdp/reconnectwm.sh|g' /etc/xrdp/sesman.ini

    # --- 2. startwm.sh：xrdp 会话启动 KDE Plasma（X11）---
    cat > /etc/xrdp/startwm.sh <<'EOF'
    #!/bin/sh
    . /etc/profile
    export PATH=/root/.nix-profile/bin:/root/.nix-profile/sbin:$PATH
    export XDG_DATA_DIRS=/root/.nix-profile/share:/usr/local/share:/usr/share
    export XDG_CONFIG_DIRS=/root/.nix-profile/etc/xdg:/etc/xdg
    # XDG_RUNTIME_DIR 兜底（pam_systemd 未建时；KDE 6 无此目录直接崩）
    if [ ! -d /run/user/0 ]; then
      mkdir -p /run/user/0
      chmod 700 /run/user/0
    fi
    export XDG_RUNTIME_DIR=/run/user/0
    export XDG_SESSION_DESKTOP=KDE
    export XDG_CURRENT_DESKTOP=KDE
    exec startplasma-x11
    EOF
    chmod +x /etc/xrdp/startwm.sh

    # --- 3. TLS 证书 + rsakeys（缺失才生成，幂等）---
    if [ ! -s /etc/xrdp/cert.pem ] || [ ! -s /etc/xrdp/key.pem ]; then
      openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 3650 \
        -subj /C=CN/ST=Shanghai/O=ide-lenovo/CN=ide-lenovo \
        -config ${pkgs.xrdp}/share/xrdp/openssl.conf \
        -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem
      chmod 600 /etc/xrdp/key.pem
    fi
    mkdir -p /run/xrdp
    if [ ! -s /run/xrdp/rsakeys.ini ]; then
      ${pkgs.xrdp}/bin/xrdp-keygen xrdp /run/xrdp/rsakeys.ini
    fi

    # --- 4. pam：xrdp-sesman 认证（nullok 允许空密码兜底 + systemd 会话建 XDG_RUNTIME_DIR）---
    cat > /etc/pam.d/xrdp-sesman <<'EOF'
    auth [success=1 default=ignore] pam_unix.so nullok
    auth requisite pam_deny.so
    auth required pam_permit.so
    account required pam_unix.so
    session optional pam_systemd.so
    EOF

    # --- 5. root 密码（xrdp 登录用；文件内容格式 root:<密码>，宿主机 docker/ide/.secrets/ 维护）---
    if [ -f /root/.secrets/xrdp-password ]; then
      chpasswd < /root/.secrets/xrdp-password
      echo "===> root 密码已从 /root/.secrets/xrdp-password 设置（xrdp 登录用）"
    else
      echo "警告: /root/.secrets/xrdp-password 不存在，root 密码未设置；xrdp 登录需空密码（pam nullok）或手动 chpasswd"
    fi

    # --- 6. dbus：系统服务 + user 服务（KDE 强依赖；容器镜像未装 dbus）---
    ln -sf ${pkgs.dbus}/etc/systemd/system/dbus.service /etc/systemd/system/dbus.service
    ln -sf ${pkgs.dbus}/etc/systemd/system/dbus.socket /etc/systemd/system/dbus.socket
    mkdir -p /etc/systemd/user/default.target.wants /etc/systemd/user/sockets.target.wants
    ln -sf ${pkgs.dbus}/etc/systemd/user/dbus.service /etc/systemd/user/default.target.wants/dbus.service
    ln -sf ${pkgs.dbus}/etc/systemd/user/dbus.socket /etc/systemd/user/sockets.target.wants/dbus.socket
    # plasma-workspace 的 systemd user units（plasmashell 等；目录不存在则跳过）
    if [ -d ${pkgs.kdePackages.plasma-workspace}/lib/systemd/user ]; then
      ln -sf ${pkgs.kdePackages.plasma-workspace}/lib/systemd/user/* /etc/systemd/user/
    fi

    # --- 7. xrdp systemd units（模板 sed 注入 store 路径，内容不变则跳过，照 skemate 模式）---
    unit=/etc/systemd/system/xrdp.service
    tmp=$(mktemp)
    sed "s|@xrdp@|${pkgs.xrdp}|" ${./xrdp.service} > "$tmp"
    unit_changed=0
    if ! cmp -s "$tmp" "$unit"; then
      cp "$tmp" "$unit"
      unit_changed=1
    fi
    rm -f "$tmp"
    unit2=/etc/systemd/system/xrdp-sesman.service
    tmp2=$(mktemp)
    sed "s|@xrdp@|${pkgs.xrdp}|" ${./xrdp-sesman.service} > "$tmp2"
    unit2_changed=0
    if ! cmp -s "$tmp2" "$unit2"; then
      cp "$tmp2" "$unit2"
      unit2_changed=1
    fi
    rm -f "$tmp2"

    # --- 8. 启用 + 拉起（幂等；ActiveState 判断，崩溃循环不误判，照 skemate 模式）---
    mkdir -p /tmp/.xrdp
    chmod 3777 /tmp/.xrdp
    if ! /usr/bin/systemctl daemon-reload; then
      echo "警告: systemctl daemon-reload 失败，错误如上"
    fi
    for s in dbus xrdp-sesman xrdp; do
      if ! /usr/bin/systemctl enable "$s.service"; then
        echo "警告: systemctl enable $s.service 失败，错误如上（容器重启后不会自启）"
      fi
    done
    # dbus 首次启用需 start（enable 不 start）
    state=$(/usr/bin/systemctl show -p ActiveState --value dbus.service 2>/dev/null || echo unknown)
    if [ "$state" != "active" ]; then
      if ! /usr/bin/systemctl start dbus.service; then
        echo "警告: dbus.service 启动失败，错误如上"
      fi
    fi
    # xrdp 重启条件：unit 变更（store 路径变）或服务未存活（崩溃循环）
    if [ "$unit_changed" = "1" ] || [ "$unit2_changed" = "1" ]; then
      /usr/bin/systemctl restart xrdp-sesman.service xrdp.service
    else
      for s in xrdp-sesman xrdp; do
        state=$(/usr/bin/systemctl show -p ActiveState --value $s.service 2>/dev/null || echo unknown)
        if [ "$state" != "active" ]; then
          /usr/bin/systemctl restart $s.service
        fi
      done
    fi
    sleep 2
    for s in xrdp-sesman xrdp; do
      state=$(/usr/bin/systemctl show -p ActiveState --value $s.service 2>/dev/null || echo unknown)
      if [ "$state" = "active" ]; then
        echo "===> $s.service 已运行"
      else
        echo "警告: $s.service 未存活（当前状态 $state ，可能崩溃循环），最近日志："
        /usr/bin/journalctl -u $s.service -n 10 --no-pager 2>/dev/null || true
      fi
    done
  '';
}
