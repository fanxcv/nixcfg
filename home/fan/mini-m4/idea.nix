# IDEA 插件声明式安装（mini-m4 专属；IDEA 由 JetBrains Toolbox 管理，nix 只管插件）
# 机制：插件 zip 解压后放入 ~/Library/Application Support/JetBrains/IntelliJIdea<版本>/plugins/
# 注意：Toolbox 升级 IDEA 会生成新版本目录（IntelliJIdea2026.2 → ...），升级后需同步改路径

{ pkgs, ... }:
let
  # Claude Code 官方插件（JetBrains Marketplace id=27310）
  claudeCodePlugin = pkgs.fetchzip {
    url = "https://plugins.jetbrains.com/plugin/download?pluginId=27310&version=0.1.14-beta";
    sha256 = "sha256-usZ6r0YZrOERPf7MO8aq9cAU25yWggOa6avNEGwzgJY=";
  };
in
{
  home.file."Library/Application Support/JetBrains/IntelliJIdea2026.2/plugins/claude-code-jetbrains-plugin" =
    {
      source = claudeCodePlugin;
      recursive = true;
    };
}
