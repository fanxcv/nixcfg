# Finder 声明（system.defaults.finder）
{ config, ... }:
let
  userHome = config.users.users.${config.system.primaryUser}.home;
in
{
  system.defaults.finder = {
    # 废纸篓中存放超过 30 天的项目自动删除
    FXRemoveOldTrashItems = true;
    # 新窗口默认列表视图（Nlsv = List View）
    FXPreferredViewStyle = "Nlsv";
    # 新窗口默认打开个人目录
    NewWindowTarget = "Home";
    # 桌面显示外置硬盘
    ShowExternalHardDrivesOnDesktop = true;
    # 桌面不显示内部系统硬盘
    ShowHardDrivesOnDesktop = false;
    # 桌面显示可移动介质
    ShowRemovableMediaOnDesktop = true;
  };

  # 列表视图默认按修改日期降序排序（最新在上）。
  # Finder 排序状态存于嵌套 plist（FK_StandardViewSettings / StandardViewSettings 下的
  # sortColumn + 各列 ascending 标志），system.defaults 无法表达，故用 PlistBuddy
  # 精准修改，保留各机器原有列布局。
  system.activationScripts.finderSortOrder.text = ''
    finderPlist="${userHome}/Library/Preferences/com.apple.finder.plist"
    pb=/usr/libexec/PlistBuddy
    asUser() { launchctl asuser "$(id -u -- ${config.system.primaryUser})" sudo --user=${config.system.primaryUser} -- "$@"; }

    for settings in FK_StandardViewSettings StandardViewSettings; do
      for view in ExtendedListViewSettingsV2 ListViewSettings; do
        base=":''${settings}:''${view}"

        # 排序列：存在则改，缺失则建（兼容全新系统）
        if asUser "''${pb}" -c "Print ''${base}:sortColumn" "''${finderPlist}" >/dev/null 2>&1; then
          asUser "''${pb}" -c "Set ''${base}:sortColumn dateModified" "''${finderPlist}"
        else
          asUser "''${pb}" -c "Add ''${base}:sortColumn string dateModified" "''${finderPlist}"
        fi

        # 修改日期列方向：ascending=false 即降序，保留其余列设置
        i=0
        while :; do
          col=$(asUser "''${pb}" -c "Print ''${base}:columns:''${i}:identifier" "''${finderPlist}" 2>/dev/null) || break
          if [ "''${col}" = "dateModified" ]; then
            if asUser "''${pb}" -c "Print ''${base}:columns:''${i}:ascending" "''${finderPlist}" >/dev/null 2>&1; then
              asUser "''${pb}" -c "Set ''${base}:columns:''${i}:ascending false" "''${finderPlist}"
            else
              asUser "''${pb}" -c "Add ''${base}:columns:''${i}:ascending bool false" "''${finderPlist}"
            fi
            break
          fi
          i=$((i+1))
        done
      done
    done

    # 重启 Finder 使排序设置生效
    launchctl asuser "$(id -u -- ${config.system.primaryUser})" sudo --user=${config.system.primaryUser} -- killall Finder 2>/dev/null || true
  '';
}
