# Microsoft Edge 扩展数据备份 + 更新服务禁用（三台 Mac 共享；清单 ↔ wanted.yaml edge_extensions/edge_extension_backups）
# 安装机制：Edge 129+ 已禁用 External Extensions JSON（disable_reasons=8192，见 hosts/_darwin_/base/edge-policy.nix），
#   扩展安装由系统层 ExtensionSettings 策略接管（edge-policy.nix，root 写 Managed Preferences）
# 本文件职责：
#   1. 清理遗留 External Extensions JSON 目录（旧机制残留，避免 Edge 扫描）
#   2. 数据备份：Local Extension Settings/<id>（leveldb，含代理配置/TOTP 密钥）→ tar | age 加密
#      → ~/.secrets/edge-ext/<id>.tar.age；本地目录缺失且有备份时激活自动恢复（重建机器场景）
#      前提：Edge 未运行（运行中拷 leveldb 会损坏）；在跑则警告跳过，退出后重跑部署生效
#   3. 禁用/拆卸 Edge 自动更新服务（EdgeUpdater）
{
  pkgs,
  lib,
  tools,
  ...
}:
let
  ext = import ./edge-ext/data.nix;
  # 本仓库统一 age 公钥（secrets/keys.nix 同源，各机器一把）
  agePubkey = "age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204";
  backups = ext.backups;
in
{
  home.activation.edgeExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umask 077
    edge_root="$HOME/Library/Application Support/Microsoft Edge"
    ext_dir="$edge_root/External Extensions"
    storage_dir="$edge_root/Default/Local Extension Settings"
    backup_dir="$HOME/.secrets/edge-ext"
    mkdir -p "$backup_dir"

    # 1. 清理旧机制遗留（External Extensions JSON 已被 Edge 129+ 禁用，删除避免无谓扫描）
    if [ -d "$ext_dir" ]; then
      rm -f "$ext_dir"/*.json
      # 目录空了则连目录一起删（Edge 启动扫描目录不存在时跳过）
      rmdir "$ext_dir" 2>/dev/null || true # 目录非空（用户自留文件）时保留，属预期
    fi

    # 2. 数据备份/恢复（仅 Edge 未运行时；leveldb 运行中拷贝会损坏，跳过属预期并提示）
    if pgrep -f "Microsoft Edge.app/Contents/MacOS" > /dev/null 2>&1; then
      echo "警告: Edge 正在运行，跳过扩展数据备份（退出 Edge 后重新部署生效）"
    else
      ${builtins.concatStringsSep "\n" (
        map (bid: ''
          if [ -d "$storage_dir/${bid}" ]; then
            tmp_tar="$(mktemp "$backup_dir/.edge-ext.XXXXXX.tar")"
            chmod 600 "$tmp_tar"
            if tar -C "$storage_dir" -cf "$tmp_tar" "${bid}"; then
              ${pkgs.age}/bin/age -e -r "${agePubkey}" -o "$backup_dir/${bid}.tar.age" "$tmp_tar"
            else
              echo "警告: 扩展 ${bid} 数据打包失败，跳过备份" >&2
            fi
            rm -f "$tmp_tar"
          elif [ -f "$backup_dir/${bid}.tar.age" ]; then
            # 本地数据缺失（重建机器/新扩展）→ 从备份恢复
            tmp_restore="$(mktemp "$backup_dir/.edge-restore.XXXXXX.tar")"
            chmod 600 "$tmp_restore"
            if ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" -o "$tmp_restore" "$backup_dir/${bid}.tar.age"; then
              mkdir -p "$storage_dir"
              tar -C "$storage_dir" -xf "$tmp_restore"
            else
              echo "警告: 扩展 ${bid} 数据恢复失败（备份可能损坏）" >&2
            fi
            rm -f "$tmp_restore"
          fi
        '') backups
      )}
    fi
  '';
  # 禁用/拆卸 Edge 自动更新服务（EdgeUpdater）
  # 痕迹三处：~/Library/LaunchAgents/com.microsoft.EdgeUpdater.wake.plist（每小时 --wake-all 检查更新）、
  #   ~/Library/Application Support/Microsoft/EdgeUpdater/（组件本体，Edge 主程序会自行拉起 updater）、launchctl 状态
  # 拆法：bootout 卸载 → kill updater 进程 → 删 plist → launchctl disable 持久标记（xpc 数据库，Edge 重建 plist 也无法复活）
  #   → 删 EdgeUpdater 组件目录（macOS 允许 unlink 运行中文件，Edge 运行中也直接删；Edge 重新下载组件时下次部署再删）
  home.activation.disableEdgeUpdater = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    label="com.microsoft.EdgeUpdater.wake"
    agent_file="$HOME/Library/LaunchAgents/$label.plist"
    uid="$(id -u)"

    # 1. 卸载当前加载的服务（未加载属预期失败）
    launchctl bootout "gui/$uid/$label" 2>/dev/null || true # 服务未加载时 bootout 报错，属预期

    # 2. 杀掉可能运行的 updater 进程（无则忽略）
    pkill -f "EdgeUpdater" 2>/dev/null || true # 无进程时 pkill 返回 1，属预期

    # 3. 删除 plist（Edge 可能重建，第 4 步 disable 标记兜底）
    rm -f "$agent_file"

    # 4. 持久禁用标记：即使 plist 被 Edge 重建也无法运行（launchctl enable 可恢复）
    launchctl disable "gui/$uid/$label"

    # 5. 删除更新组件目录（Edge 主程序会自行拉起 updater，必须拆本体；Edge 运行中删除安全）
    rm -rf "$HOME/Library/Application Support/Microsoft/EdgeUpdater"
  '';
}
