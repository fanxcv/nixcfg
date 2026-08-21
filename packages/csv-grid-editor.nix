# CSV Grid Editor: CSV & TSV Viewer（RobinReiche.csv-grid-editor）官方 vsix 直链自打包
# 背景：nixpkgs 主市场无此扩展；补市场（nix-vscode-extensions marketplace-release）缓存滞后——
#   仓库 data/cache 停在 1.16.0，而市场最新为 1.18.4（多版滞后）。故官方 marketplace vsix 直链打包。
# 布局：与 nix-vscode-extensions 一致，$out/share/vscode/extensions/<publisher.name-version>/ 直接含 package.json
#   （server 端 buildEnv 的 extensions.json 生成器遍历 $d/package.json，故不可保留 vsix 内层 extension/ 子目录）。
# 版本升级：改 version + 下载后重算 hash（nix-prefetch-url <同上 URL>；1.18.4 实测 sha256-sKGZiHi/02++Ig6TBfFk4kRG/XLXIharRgpyPEJKt/s=）
{ lib, stdenv, fetchurl, unzip }:
stdenv.mkDerivation (finalAttrs: {
  pname = "vscode-extension-robinreiche-csv-grid-editor";
  version = "1.18.4";

  # nixpkgs 扩展包标准标识（HM programs.vscode 生成 extensions.json 时经 vscode-utils 读取）
  vscodeExtUniqueId = "RobinReiche.csv-grid-editor";
  vscodeExtPublisher = "RobinReiche";
  vscodeExtName = "csv-grid-editor";

  src = fetchurl {
    url = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/RobinReiche/vsextensions/csv-grid-editor/${finalAttrs.version}/vspackage";
    hash = "sha256-sKGZiHi/02++Ig6TBfFk4kRG/XLXIharRgpyPEJKt/s=";
  };

  nativeBuildInputs = [ unzip ];

  dontUnpack = true; # vspackage 后缀 stdenv 不识别，unpackPhase 直接炸，改 installPhase 自解压

  installPhase = ''
    runHook preInstall
    # vsix 含 extension/（内容根）+ [Content_Types].xml / extension.vsixmanifest 元文件
    unzip -q "$src" -d "$out"
    mkdir -p "$out/share/vscode/extensions"
    mv "$out/extension" "$out/share/vscode/extensions/robinreiche.csv-grid-editor-${finalAttrs.version}"
    rm -f "$out/[Content_Types].xml" "$out/extension.vsixmanifest"
    runHook postInstall
  '';
})
