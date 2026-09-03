# 透明面板主题（macOS 风格）：基于 Breeze，panel-background 全透明（fill-opacity:1 → 0）
# 主题目录只含 panel-background 相关文件，其余元素回退 default 主题（Plasma 主题 fallback 机制）
# 生成方式：复制 default 主题的 panel-background.svgz 解压 → sed 全透明 → 存 .svg 明文
# 与 plasma.panels.nix 的 opacity=translucent 配合：面板背景由主题决定（透明），opacity 模式仅控制前缀选择
{
  xdg.dataFile = {
    "plasma/desktoptheme/nixcfg-transparent/metadata.json".source = ./theme/nixcfg-transparent/metadata.json;
    "plasma/desktoptheme/nixcfg-transparent/widgets/panel-background.svg".source = ./theme/nixcfg-transparent/widgets/panel-background.svg;
    "plasma/desktoptheme/nixcfg-transparent/solid/widgets/panel-background.svg".source = ./theme/nixcfg-transparent/solid/widgets/panel-background.svg;
    "plasma/desktoptheme/nixcfg-transparent/translucent/widgets/panel-background.svg".source = ./theme/nixcfg-transparent/translucent/widgets/panel-background.svg;
  };

  programs.plasma.workspace.theme = "nixcfg-transparent";
}
