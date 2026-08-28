# KDE 界面中文（声明式 plasma-localerc）——所有 NixOS 机生效
# 背景：nix-pve 的中文界面原是运行时文件（手动设置写 ~/.config/plasma-localerc，经 /persist 持久化），
#   仓库无声明；全新装机（nix-book）即英文。此处声明化：plasma-manager configFile（INI 结构）写入
#   [Translations] Language=zh_CN（KDE 6 界面语言读此，不随 LANG 变化）+ [Formats] LANG=zh_CN.UTF-8
#   系统 locale 见 hosts/_nixos_/i18n/locale.nix（defaultLocale zh_CN.UTF-8）；
#   终端/SSH 保持 en_US 见 ./locale.nix（home.language.base）
_: {
  programs.plasma.configFile."plasma-localerc" = {
    Formats = {
      LANG = "zh_CN.UTF-8";
    };
    Translations = {
      Language = "zh_CN";
    };
  };
}
