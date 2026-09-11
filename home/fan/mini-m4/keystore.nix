# Android release 签名密钥与凭据由 nix 管理（age 加密，无兜底链）
#   明文源：secrets/source/hosts/mini-m4/{<app>-android-release.p12,<app>-android-key.properties}（gitignore）
#   加密件：secrets/hosts/mini-m4/*.age（可提交 git）
#   部署：  激活解密到 ~/.config/（600），失败即部署失败
#   keystore 路径与各 app 构建配置的默认值一致：
#     bill-app  → ~/.config/bill-app-android-release.p12（~/code/bill-app/Makefile RELEASE_KEYSTORE_PATH）
#     hc-sh-app → ~/.config/hc-sh-app-android-release.p12（hc-flutter/android/key.properties 指向）
{
  pkgs,
  lib,
  config,
  ...
}:
let
  decrypt = name: ''
    umask 077
    ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" \
      -o "${config.home.homeDirectory}/.config/${name}" ${../../../secrets/hosts/mini-m4/${name}.age}
  '';
in
{
  # 统一 secrets 架构（见 _common_/secrets.nix）：activation 直接 age -d，失败即部署失败
  home.activation.decryptAndroidKeystores = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    builtins.concatStringsSep "\n" [
      (decrypt "bill-app-android-release.p12")
      (decrypt "bill-app-android-key.properties")
      (decrypt "hc-sh-app-android-release.p12")
      (decrypt "hc-sh-app-android-key.properties")
    ]
  );
}
