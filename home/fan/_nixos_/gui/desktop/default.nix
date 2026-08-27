# NixOS 桌面层（Wayland 会话 + XDG 目录 + plasma 定制拆分，tsln 同款）
{ tools, ... }:
{
  imports = tools.scan ./.;

  # Wayland 原生应用（Electron/Chromium 系启用 Wayland 后端）
  home.sessionVariables = {
    NIXOS_OZONE_WL = 1;
  };

  # XDG User Dirs
  xdg.userDirs = {
    enable = true;
    createDirectories = true;

    desktop = "Desktop";
    documents = "Documents";
    download = "Downloads";
    music = "Music";
    pictures = "Pictures";
    projects = "Codebases";
    templates = "Templates";
    videos = "Videos";
    publicShare = "Shared";
  };

  # 覆盖已存在的手配 user-dirs.dirs（HM 默认拒绝 clobber，NixOS 真机上文件早已存在）
  xdg.configFile."user-dirs.dirs".force = true;
}
