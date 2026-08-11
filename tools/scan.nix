# 扫描目录下所有模块并生成 imports 列表：
#   - 子目录仅当含 default.nix 时导入（import 目录 = import 其 default.nix）
#   - 包含所有 .nix 文件（排除 default.nix）
# 适用平铺模块目录（如 home/fan/_common_/）：新增模块 = 新建文件，零 import 改动
# 注意：含嵌套子目录的目录也会被整目录导入，勿在杂目录上使用

{ lib, ... }:
path:
map (f: (path + "/${f}")) (
  builtins.attrNames (
    lib.attrsets.filterAttrs (
      name: type:
      (type == "directory" && builtins.pathExists (path + "/${name}/default.nix"))
      || (
        (name != "default.nix")
        && (lib.strings.hasSuffix ".nix" name)
      )
    ) (builtins.readDir path)
  )
)
