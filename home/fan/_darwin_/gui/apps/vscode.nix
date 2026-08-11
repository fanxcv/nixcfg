# vscode 基础配置（settings + keybindings，应用本体由 homebrew cask 安装）
# 插件声明式安装需要 nix-vscode-extensions overlay（原仓库用 repos.vscode 固定插件市场），
# 本地暂未接入；需要时加 input + overlay 后按 plugins 声明，当前保持精简。

{ ... }:
{
  home.file."Library/Application Support/Code/User/settings.json".text = ''
    {
      "editor.fontFamily": "MonaspiceNe Nerd Font Mono",
      "editor.fontSize": 13,
      "editor.minimap.enabled": false,
      "editor.renderWhitespace": "none",
      "files.eol": "\n",
      "files.trimTrailingWhitespace": true,
      "workbench.colorTheme": "Default Dark Modern",
      "terminal.integrated.defaultProfile.osx": "zsh",
      "explorer.confirmDragAndDrop": false,
      "search.exclude": { "**/.git": true }
    }
  '';

  home.file."Library/Application Support/Code/User/keybindings.json".text = ''
    []
  '';
}
