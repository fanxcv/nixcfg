# 桌面会话降权（容器）：建 fan 用户（NOPASSWD sudo）+ 把 /home/fan 属主移交 fan
#   背景：桌面会话（KasmVNC/xfce）以 fan 运行、HOME=/home/fan（各机器 kasmvnc.nix 的 sessionHome），
#        而 HM 激活仍以 root 写盘（home.username/homeDirectory 未动，见 _common_/identity.nix），
#        故 HM 写下的桌面配置默认属 root，需在此改属 fan 才能回写。
#   幂等：useradd/usermod/sudoers/chown 均可重复执行；失败策略遵 AGENTS.md（禁静默吞错）
{
  lib,
  ...
}:
let
  sessionUser = "fan";
  sessionHome = "/home/fan";
  # 桌面会话会读写的宿主挂载点（compose 双挂载的 /home/fan 侧目标）。
  #   本清单须与 docker/ide/docker-compose-*.yml 的 /home/fan 侧挂载一一对应（各 15 条）。
  #   仅对其顶层做非递归 chown（保持顶层属主 fan），不递归进入——递归会波及宿主用户文件属主，
  #   且 mac 宿主（virtiofs/osxfs）可能不支持 chown，故按非关键失败仅警告。
  sessionMounts = [
    ".cache/JetBrains"
    ".config/JetBrains"
    ".local/share/JetBrains"
    ".config/skemate"
    ".local/state/mise"
    ".local/share/mise"
    ".config/mise"
    ".cache/mise"
    ".claude.json"
    ".claude"
    ".codex"
    ".pi"
    ".m2"
    ".secrets"
    # chrome 主 profile：桌面会话写 .config/chrome（chrome.nix wrapper 的 --user-data-dir）
    ".config/chrome"
  ];
  # find 排除式：-xdev 已不下降进入挂载点，此处再排除挂载点自身，避免容器层 chown 触及宿主目录
  mountExcludes = lib.concatMapStringsSep " " (rel: ''! -path "${sessionHome}/${rel}"'') sessionMounts;
in
{
  # 在桌面配置写入脚本之后执行（kasmvncBeautify → chrome → kasmvnc；ide-si 无桌面会话，DAG 容忍缺失名）
  home.activation.sessionUser = lib.hm.dag.entryAfter [ "kasmvncBeautify" "chrome" "kasmvnc" ] ''
    # 1) 建用户（幂等）：uid/gid 1000、登录 shell /bin/bash、加入 sudo 组
    if ! id -u ${sessionUser} >/dev/null 2>&1; then
      if useradd -m -u 1000 -s /bin/bash ${sessionUser}; then
        echo "===> 已创建用户 ${sessionUser}（uid 1000）"
      else
        echo "错误: useradd ${sessionUser} 失败（uid 1000 是否被占用？），激活中止"
        exit 1
      fi
    fi
    if ! id -nG ${sessionUser} | tr ' ' '\n' | grep -qx sudo; then
      if usermod -aG sudo ${sessionUser}; then
        echo "===> ${sessionUser} 已加入 sudo 组"
      else
        echo "错误: usermod -aG sudo ${sessionUser} 失败，激活中止"
        exit 1
      fi
    fi

    # 2) NOPASSWD sudoers（幂等）：mode 0440 + visudo -c 校验，失败即中止
    sudoers=/etc/sudoers.d/${sessionUser}
    echo '${sessionUser} ALL=(ALL) NOPASSWD:ALL' > "$sudoers"
    chmod 0440 "$sudoers"
    if ! visudo -cf "$sudoers"; then
      echo "错误: visudo 校验 $sudoers 失败，激活中止"
      exit 1
    fi

    # 3) 会话 home：存在且属 fan:fan（0755——fan 可读写自身配置，root 亦可）
    mkdir -p ${sessionHome}
    chown ${sessionUser}:${sessionUser} ${sessionHome}
    chmod 0755 ${sessionHome}

    # 4) 属主移交（容器层）：HM 以 root 写下的桌面配置（.config/xfce4、plank、fcitx5、.vnc、.locale、.themes…）改属 fan。
    #    -xdev 使 find 停在其它文件系统（=双挂载点），不递归穿越宿主目录：否则每次激活都要遍历宿主大目录，
    #    且 Linux 宿主上会把宿主用户文件属主改成 1000:1000（宿主 uid≠1000 即改坏）。
    #    ! -path 排除挂载点自身，其顶层属主交由下面的非递归 chown（失败仅警告，见 step 5）。
    #    容器层属主是本次降权的功能前提（fan 连自身 .config/.vnc/plank 都写不了即功能静默失效），失败即中止。
    if ! find ${sessionHome} -xdev ${mountExcludes} -exec chown ${sessionUser}:${sessionUser} {} +; then
      echo "错误: find ${sessionHome} -xdev -exec chown ${sessionUser}:${sessionUser} 失败（容器层属主未移交，桌面会话无法回写），激活中止"
      exit 1
    fi

    # 5) 挂载点顶层属主（非递归）：保持 fan 可写其顶层；不递归进入（宿主目录属主变更属预期）。
    #    mac 宿主 virtiofs/osxfs 可能不支持 chown，属非关键失败——仅警告，不中止。
    for rel in ${lib.concatStringsSep " " sessionMounts}; do
      [ -e "${sessionHome}/$rel" ] || continue
      chown ${sessionUser}:${sessionUser} "${sessionHome}/$rel" \
        || echo "警告: chown ${sessionHome}/$rel 失败（宿主目录属主未变更；mac virtiofs 可能不支持，属预期）"
    done
  '';
}
