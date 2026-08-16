# Microsoft Edge 扩展声明式安装 + 指定扩展数据备份（三台 Mac 共享，清单 ↔ wanted.yaml edge_extensions/edge_extension_backups）
# 安装机制：macOS External Extensions —— 激活期向
#   ~/Library/Application Support/Microsoft Edge/External Extensions/<CRX-ID>.json 写实体 JSON
#   （home.file 默认 symlink 到 nix store，Edge 存在不识别风险 → 统一实体文件，写入失败即中断部署）
#   update_url：Edge 商店扩展 = edge.microsoft.com/extensionwebstorebase/v1/crx；
#   Chrome 商店扩展 = clients2.google.com/service/update2/crx（6 个 Chrome-only 已用 crxid API 实测 404）
# 合并语义：该机制纯增量安装——只负责装上声明的扩展，从不删除/覆盖应用内已手动安装的扩展
# 副作用：外部安装的扩展在 edge://extensions 显示"由你的组织安装"，无法应用内卸载，改本清单（删 JSON）即移除
# 数据备份：Local Extension Settings/<id>（leveldb，含代理配置/TOTP 密钥）→ tar | age 加密
#   → ~/.secrets/edge-ext/<id>.tar.age；本地目录缺失且有备份时激活自动恢复（重建机器场景）
#   前提：Edge 未运行（运行中拷 leveldb 会损坏）；在跑则警告跳过，退出后重跑部署生效
{ pkgs, lib, ... }:
let
  # 声明式安装清单：ID -> store（edge=Edge 商店 / chrome=Chrome 商店，crxid API 实测归属）
  extensions = {
    aapbdbdomjkkjkaonfhkkikfgjllcleb = "chrome";  # Google 翻译
    bhghoamapcdpbohphigoooaddinpkbai = "chrome";  # 身份验证器（数据备份）
    dbheplacgeefjnhdacijldhfliehnhka = "chrome";  # 琉神转
    dlknjglebgomjjfaijjnebecgjbfjihk = "chrome";  # 超级拖拽
    eeagobfjdenkkddmbclomhiblgggliao = "edge";    # 暴力猴
    hihblcmlaaademjlakdpicchbjnnnkbo = "chrome";  # Proxy SwitchyOmega V3（数据备份）
    jbkfoedolllekgbhcbcoahefnbanhhlh = "edge";    # Bitwarden
    mpkodccbngfoacfalldjimigbofkhgjn = "chrome";  # Aria2 Explorer
    nmddeihindhodaigflchmkmechmjjjbc = "edge";    # QR码生成与识别
    odfafepnkmbhccpbejgmiehpchacaeak = "edge";    # uBlock Origin
  };
  # 数据备份扩展（Local Extension Settings/<id> → ~/.secrets/edge-ext/<id>.tar.age）
  backups = [ "bhghoamapcdpbohphigoooaddinpkbai" "hihblcmlaaademjlakdpicchbjnnnkbo" ];
  # 本仓库统一 age 公钥（secrets/keys.nix 同源，各机器一把）
  agePubkey = "age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204";
  edgeStoreUrl = "https://edge.microsoft.com/extensionwebstorebase/v1/crx";
  chromeStoreUrl = "https://clients2.google.com/service/update2/crx";
  updateUrl = store: if store == "chrome" then chromeStoreUrl else edgeStoreUrl;
  extIds = builtins.attrNames extensions;
in
{
  home.activation.edgeExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umask 077
    edge_root="$HOME/Library/Application Support/Microsoft Edge"
    ext_dir="$edge_root/External Extensions"
    storage_dir="$edge_root/Default/Local Extension Settings"
    backup_dir="$HOME/.secrets/edge-ext"
    mkdir -p "$ext_dir" "$backup_dir"

    # 1. 声明式安装：写实体 JSON（先写临时文件再 mv，避免 Edge 读到半截内容）
    ${builtins.concatStringsSep "\n" (map (id: ''
      url="${updateUrl extensions.${id}}"
      tmp="$(mktemp "$ext_dir/.edge-ext.XXXXXX")"
      printf '{"update_url":"%s"}' "$url" > "$tmp"
      chmod 644 "$tmp"
      mv "$tmp" "$ext_dir/${id}.json"
    '') extIds)}

    # 2. 数据备份/恢复（仅 Edge 未运行时；leveldb 运行中拷贝会损坏，跳过属预期并提示）
    if pgrep -f "Microsoft Edge.app/Contents/MacOS" > /dev/null 2>&1; then
      echo "警告: Edge 正在运行，跳过扩展数据备份（退出 Edge 后重新部署生效）"
    else
      ${builtins.concatStringsSep "\n" (map (bid: ''
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
      '') backups)}
    fi
  '';
}
