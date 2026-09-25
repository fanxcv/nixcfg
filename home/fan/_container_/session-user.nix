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
  # 桌面会话会读写的宿主挂载点（compose 双挂载的 /home/fan 侧目标）：
  #   chown 会经 bind mount 波及宿主目录属主——Linux 宿主上这些目录本就属主用户（uid 1000），
  #   预期无副作用；mac 宿主（virtiofs/osxfs）可能忽略或报错，按非关键失败警告。
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
  ];
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

    # 4) 属主移交：HM 以 root 写下的桌面配置（.config/xfce4、plank、fcitx5、.vnc、.locale、.themes…）
    #    连同双挂载目标一并改属 fan；失败非关键（会话或仍只读），警告不中止
    chown -R ${sessionUser}:${sessionUser} ${sessionHome} \
      || echo "警告: chown -R ${sessionHome} 失败（部分文件仍属 root，桌面会话可能无法回写）"

    # 5) 双挂载 /home/fan 侧宿主目录目标（递归已覆盖，此处显式列出，幂等；属主变更波及宿主属主，预期）
    for rel in ${lib.concatStringsSep " " sessionMounts}; do
      [ -e "${sessionHome}/$rel" ] || continue
      chown ${sessionUser}:${sessionUser} "${sessionHome}/$rel" \
        || echo "警告: chown ${sessionHome}/$rel 失败（宿主目录属主未变更）"
    done
  '';
}
