# TTY 控制台渲染（kmscon）：高清字体 + CJK（tsln 同款）
{ lib, pkgs, ... }:
{
  services.kmscon = {
    enable = true;
    package = pkgs.kmscon;

    hwRender = true;
    extraConfig = lib.strings.concatStringsSep "\n" [
      "font-size=12"
      "font-dpi=144"
    ];

    fonts = [
      {
        name = "Monaspace Neon";
        package = pkgs.monaspace;
      }
      {
        name = "Monaspace Neon NF";
        package = pkgs.nerd-fonts.monaspace;
      }
      {
        name = "Noto Sans CJK SC";
        package = pkgs.noto-fonts-cjk-sans;
      }
    ];
  };
}
