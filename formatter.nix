# treefmt 格式化配置（nix fmt = nixfmt + statix 检查）
_: {
  # 用于定位项目根（treefmt 向上查找）
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    statix.enable = true;
    statix.disabled-lints = [
      "manual_inherit_from"
    ];
  };
}
