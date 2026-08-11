# chromium（应用本体由 homebrew cask 安装）
# 声明式安装扩展（home-manager 启动时静默安装到 Chromium）
{
  programs.chromium = {
    enable = true;
    package = null;
    extensions = [
      { id = "ddkjiahejlhfcafbddmgiahcphecmpfh"; } # uBlock Origin Lite
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
      { id = "bpoadfkcbjbfhfodiogcnhhhpibjhbnh"; } # Translator
    ];
  };
}
