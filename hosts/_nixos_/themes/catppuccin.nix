# Catppuccin 系统级主题（tsln 同款策略）：enable 总开关 + autoEnable 关（target 手动开）
# 全局 flavor mocha（grub/plymouth 深色），SDDM 显式 latte；用户层（home/_common_）flavor latte
{ lib, ... }:
{
  catppuccin = {
    enable = true;
    autoEnable = false;

    flavor = lib.mkDefault "mocha";
    accent = lib.mkDefault "blue";

    # 主题包缓存（whiskers 生成物缓存，加速重建）
    cache.enable = true;

    grub.enable = lib.mkDefault true;

    plymouth.enable = lib.mkDefault true;

    sddm.enable = lib.mkDefault true;
    sddm.flavor = lib.mkDefault "latte";
  };
}
