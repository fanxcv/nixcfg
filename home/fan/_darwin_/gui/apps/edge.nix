# Microsoft Edge：两个指定扩展的本地数据备份/还原（三台 Mac 共享）
# 边界（2026-10 收敛）：nix 只管 Edge **本体**（homebrew cask，见 hosts/_darwin_/base/apps.nix）；
#   扩展的安装与同步全部交给 Edge 自身账号同步；EdgeUpdater 的拆卸已撤出，nix 不再干预 Edge 更新。
# 本文件职责：备份/还原两个指定扩展的本地数据（Local Extension Settings/<id>，即 chrome.storage.local，
#   含登录态/配置）：数据存在 → 备份到 ~/.secrets/edge-ext/<id>.tar.age；
#   插件已安装但数据缺失 → 从备份还原。其余扩展 nix 不管。
{
  pkgs,
  lib,
  ...
}:
let
  # 需要备份/还原数据的扩展（唯一需要 nix 介入的两项；其余走 Edge 账号同步）
  #   bhghoamapcdpbohphigoooaddinpkbai  身份验证器
  #   hihblcmlaaademjlakdpicchbjnnnkbo  Proxy SwitchyOmega V3
  backedUpExtensions = [
    "bhghoamapcdpbohphigoooaddinpkbai"
    "hihblcmlaaademjlakdpicchbjnnnkbo"
  ];
  # 仓库统一 age 公钥（与 secrets/keys.nix 同源）
  agePubkey = "age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204";
in
{
  home.activation.edgeExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umask 077
    edge_root="$HOME/Library/Application Support/Microsoft Edge"
    profile="Default" # 若用其他 Edge profile（Profile 1 等），改此处
    storage_dir="$edge_root/$profile/Local Extension Settings"
    installed_dir="$edge_root/$profile/Extensions"
    backup_dir="$HOME/.secrets/edge-ext"
    mkdir -p "$backup_dir"

    # 仅 Edge 未运行时操作（leveldb 运行中拷贝会损坏）；在跑则警告跳过，退出 Edge 后重跑部署生效
    if pgrep -f "Microsoft Edge.app/Contents/MacOS" > /dev/null 2>&1; then
      echo "警告: Edge 正在运行，跳过扩展数据备份/还原（退出 Edge 后重新部署生效）"
    else
      ${builtins.concatStringsSep "\n" (
        map (bid: ''
          if [ -d "$storage_dir/${bid}" ]; then
            # 数据存在 → 备份（覆盖旧备份）
            tmp_tar="$(mktemp "$backup_dir/.edge-ext.XXXXXX.tar")"
            chmod 600 "$tmp_tar"
            if tar -C "$storage_dir" -cf "$tmp_tar" "${bid}"; then
              ${pkgs.age}/bin/age -e -r "${agePubkey}" -o "$backup_dir/${bid}.tar.age" "$tmp_tar"
            else
              echo "警告: 扩展 ${bid} 数据打包失败，跳过备份" >&2
            fi
            rm -f "$tmp_tar"
          elif [ -d "$installed_dir/${bid}" ] && [ -f "$backup_dir/${bid}.tar.age" ]; then
            # 插件已安装（Edge 账号同步装回）但本地数据缺失 → 还原备份
            tmp_restore="$(mktemp "$backup_dir/.edge-restore.XXXXXX.tar")"
            chmod 600 "$tmp_restore"
            if ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" -o "$tmp_restore" "$backup_dir/${bid}.tar.age"; then
              mkdir -p "$storage_dir"
              tar -C "$storage_dir" -xf "$tmp_restore"
            else
              echo "警告: 扩展 ${bid} 数据还原失败（备份可能损坏）" >&2
            fi
            rm -f "$tmp_restore"
          fi
        '') backedUpExtensions
      )}
    fi
  '';
}
