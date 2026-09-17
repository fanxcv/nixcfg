# macOS 三台机器共用系统层组装（原 hosts/<机>/default.nix 三份重复，上提至此）
# 机器层 hosts/<机>/ 只保留机器差异文件；flake.nix mkDarwinConfig 同时挂入本目录与机器目录
# 自动扫描 base/gui/i18n/kernel 子目录（各含 default.nix）
{
  tools,
  ...
}:
{
  imports =
    (map tools.relative [
      "hosts/_common_/base"
      "hosts/_common_/i18n"

      "users/fan"
    ])
    ++ (tools.scan ./.);
}
