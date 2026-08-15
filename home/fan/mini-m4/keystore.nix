# bill-app（橘子账本）Android release 签名密钥由 nix 管理（agenix）
#   源文件：secrets/source/bill-app-android-release.p12（明文，gitignore）
#   加密：  secrets/bill-app-android-release.p12.age（age 加密入库，可提交 git）
#   部署：  激活自动解密到 ~/.config/bill-app-android-release.p12（600）
#   （路径与 bill-app Makefile 的 RELEASE_KEYSTORE_PATH 默认值一致，见 ~/code/bill-app/Makefile）
{ pkgs, lib, config, ... }:
{
  # 统一 secrets 架构（见 _common_/secrets.nix）：activation 直接 age -d，失败即部署失败
  home.activation.decryptBillKeystore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umask 077
    ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" \
      -o "${config.home.homeDirectory}/.config/bill-app-android-release.p12" ${../../../secrets/bill-app-android-release.p12.age}
  '';
}
