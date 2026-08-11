# 跨平台 i18n（时区等）
# 新增模块：新建 .nix 文件即生效（tools.scan）

{ tools, ... }:
{
  imports = tools.scan ./.;
}
