# Catppuccin 全局默认（tsln 同款策略）：enable 总开关 + autoEnable 关（target 手动开）
# flavor latte 亮色 + blue 强调；CLI 工具类预设 mocha 深色（具体 target enable 未开不生效）
{ lib, ... }:
{
  catppuccin = {
    enable = true;
    autoEnable = false;

    flavor = lib.mkDefault "latte";
    accent = lib.mkDefault "blue";

    # CLI 工具预设（flavor 覆盖全局 latte；enable 未开不生效，仅预设）
    bat.flavor = lib.mkDefault "mocha";
    eza.flavor = lib.mkDefault "mocha";
    k9s.flavor = lib.mkDefault "mocha";
    tmux.flavor = lib.mkDefault "mocha";
    zellij.flavor = lib.mkDefault "mocha";
    lazygit.flavor = lib.mkDefault "mocha";
    starship.flavor = lib.mkDefault "mocha";
    atuin.flavor = lib.mkDefault "mocha";
    btop.flavor = lib.mkDefault "mocha";
    delta.flavor = lib.mkDefault "mocha";
    fzf.flavor = lib.mkDefault "mocha";
    helix.flavor = lib.mkDefault "mocha";
    yazi.flavor = lib.mkDefault "mocha";
    alacritty.flavor = lib.mkDefault "mocha";
    zsh-syntax-highlighting.flavor = lib.mkDefault "mocha";
  };
}
