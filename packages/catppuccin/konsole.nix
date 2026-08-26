# Catppuccin Konsole 配色（nixpkgs 26.05 无此包，固定 rev 自打包；同 tsln1998/nixcfg 的 packages/catppuccin/konsole.nix）
# 输出 themes/* 全部 flavor 的 colorscheme，home 层软链到 ~/.local/share/konsole/ 后按名引用
# githubBase：由 packages/default.nix 从 tools/config.nix 传入（GitHub 加速；内部拼 https://${githubBase}/…，无 scheme）
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  githubBase ? "github.com",
}:
let
  owner = "catppuccin";
  repo = "konsole";
  rev = "3b64040e3f4ae5afb2347e7be8a38bc3cd8c73a8";
  hash = "sha256-d5+ygDrNl2qBxZ5Cn4U7d836+ZHz77m6/yxTIANd9BU=";
in
stdenvNoCC.mkDerivation {
  pname = "catppuccin-konsole";
  version = builtins.substring 0 6 rev;

  src = fetchFromGitHub {
    inherit
      owner
      repo
      rev
      hash
      githubBase
      ;
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp $src/themes/* $out/
    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://github.com/${owner}/${repo}";
    description = "Soothing pastel theme for Konsole";
    license = licenses.mit;
  };
}
