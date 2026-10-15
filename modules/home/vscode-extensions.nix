# VSCode 扩展单一清单——加/删/改插件只改本文件：客户端三 profile 与 vscode-server 端扩展均由它派生。
# 本文件同时是 home 模块（tools.scan 会导入 modules/home/*.nix 全部 .nix），清单经 _module.args
# 注入供 modules/home/vscode.nix 取用；flake.nix 无 pkgs，直接 import 读静态 unfree 字段生成白名单。
# 字段：
#   id       扩展唯一 id（publisher.name），供唯一性校验与检索
#   pkg      包引用，写成 pkgs 的函数延迟解析：flake.nix 构造 pkgs 时须先读 unfree 白名单
#            （allowUnfreePredicate 早于模块求值），直接引用 pkgs 会与之循环依赖
#   profiles 进哪些客户端 profile（default/python/go；vscode --profile <名> 启动，公共部分自动并入）
#   client   是否装客户端
#   server   是否装 vscode-server 端（UI 类扩展置 false）
#   unfree   可选：nixpkgs 包名，flake.nix 据此生成 unfree 白名单
# 来源三路（禁本地自打包，packages/ 不再收 vscode 扩展）：
#   market  = pkgs.vscode-extensions（nixpkgs 内置，无 IFD）
#   release = pkgs.repos.vscode.vscode-marketplace-release（nix-community，IFD；仅补 nixpkgs 缺失项）
#   unstable= pkgs.repos.unstable.vscode-extensions（独立 unstable 通道，无 IFD；仅当主通道版本有已知缺陷时用）
let
  allProfiles = [
    "default"
    "python"
    "go"
  ];
in
{
  _module.args.vscodeExtensionManifest = [
    # --- 公共（三 profile 共用）---
    {
      id = "MS-CEINTL.vscode-language-pack-zh-hans";
      pkg = pkgs: pkgs.vscode-extensions.ms-ceintl.vscode-language-pack-zh-hans;
      profiles = allProfiles;
      client = true;
      server = true;
      unfree = "vscode-extension-ms-ceintl-vscode-language-pack-zh-hans";
    }
    {
      id = "github.github-vscode-theme";
      pkg = pkgs: pkgs.vscode-extensions.github.github-vscode-theme;
      profiles = allProfiles;
      client = true;
      server = false; # 主题：server 端无 UI 意义
    }
    {
      id = "PKief.material-icon-theme";
      pkg = pkgs: pkgs.vscode-extensions.pkief.material-icon-theme;
      profiles = allProfiles;
      client = true;
      server = false; # 文件图标：server 端无 UI 意义
    }
    {
      id = "oderwat.indent-rainbow";
      pkg = pkgs: pkgs.vscode-extensions.oderwat.indent-rainbow;
      profiles = allProfiles;
      client = true;
      server = true;
    }
    {
      id = "codezombiech.gitignore";
      pkg = pkgs: pkgs.vscode-extensions.codezombiech.gitignore;
      profiles = allProfiles;
      client = true;
      server = true;
    }
    {
      id = "waderyan.gitblame";
      pkg = pkgs: pkgs.vscode-extensions.waderyan.gitblame;
      profiles = allProfiles;
      client = true;
      server = true;
    }
    {
      id = "mhutchie.git-graph";
      pkg = pkgs: pkgs.vscode-extensions.mhutchie.git-graph;
      profiles = allProfiles;
      client = true;
      server = true;
      unfree = "vscode-extension-mhutchie-git-graph";
    }
    {
      id = "editorconfig.editorconfig";
      pkg = pkgs: pkgs.vscode-extensions.editorconfig.editorconfig;
      profiles = allProfiles;
      client = true;
      server = true;
    }
    {
      id = "redhat.vscode-yaml";
      pkg = pkgs: pkgs.vscode-extensions.redhat.vscode-yaml;
      profiles = allProfiles;
      client = true;
      server = true;
    }
    {
      id = "usernamehw.errorlens";
      pkg = pkgs: pkgs.vscode-extensions.usernamehw.errorlens;
      profiles = allProfiles;
      client = true;
      server = false; # 编辑器 UI：server 端无意义
    }
    {
      id = "humao.rest-client";
      pkg = pkgs: pkgs.vscode-extensions.humao.rest-client;
      profiles = allProfiles;
      client = true;
      server = true;
    }
    {
      id = "yzhang.markdown-all-in-one";
      pkg = pkgs: pkgs.vscode-extensions.yzhang.markdown-all-in-one;
      profiles = allProfiles;
      client = true;
      server = true;
    }
    {
      id = "robinreiche.csv-grid-editor";
      pkg = pkgs: pkgs.repos.vscode.vscode-marketplace-release.robinreiche.csv-grid-editor; # CSV/TSV 网格查看编辑（nixpkgs 无）
      profiles = allProfiles;
      client = true;
      server = true;
    }
    {
      id = "highagency.pencildev";
      pkg = pkgs: pkgs.repos.vscode.vscode-marketplace-release.highagency.pencildev; # Pencil / pen.dev 设计稿编辑（nixpkgs 无）
      profiles = allProfiles;
      client = true;
      server = true; # .pen 编辑器与 MCP server 在 workspace 侧运行，远程开发时 server 端需要
      unfree = "vscode-extension-highagency-pencildev";
    }
    {
      id = "ms-vscode-remote.remote-ssh";
      # 走 unstable 通道取 0.128.0：主通道 nixpkgs 仍锁 0.122.0，该版把 IPC socket 建在
      # $TMPDIR（mac 上 /var/folders/xx/<24字符>/T 共 49 字节）+ 40 字符随机名 = 113 字节，
      # 超 macOS sun_path 103 上限 → listen EINVAL → 5 秒一轮无限重连（upstream issue 11672/11677）；
      # 0.128.0 起按 MAX_UNIX_SOCKET_PATH_LENGTH 截断随机名。engines 要求 VSCode ≥1.133。
      # 主通道 nixpkgs 升到 ≥0.128.0 后即可回落 pkgs.vscode-extensions
      pkg = pkgs: pkgs.repos.unstable.vscode-extensions.ms-vscode-remote.remote-ssh;
      profiles = allProfiles;
      client = true;
      server = false; # 客户端侧远程连接器
      unfree = "vscode-extension-ms-vscode-remote-remote-ssh";
    }

    # --- python profile ---
    {
      id = "ms-python.python";
      pkg = pkgs: pkgs.vscode-extensions.ms-python.python;
      profiles = [ "python" ];
      client = true;
      server = true;
    }
    {
      id = "ms-python.debugpy";
      pkg = pkgs: pkgs.vscode-extensions.ms-python.debugpy;
      profiles = [ "python" ];
      client = true;
      server = true;
    }
    {
      id = "ms-python.isort";
      pkg = pkgs: pkgs.vscode-extensions.ms-python.isort;
      profiles = [ "python" ];
      client = true;
      server = true;
    }
    {
      id = "MS-python.vscode-pylance";
      pkg = pkgs: pkgs.vscode-extensions.ms-python.vscode-pylance;
      profiles = [ "python" ];
      client = true;
      server = true;
      unfree = "vscode-extension-MS-python-vscode-pylance";
    }
    {
      id = "ms-python.autopep8";
      pkg = pkgs: pkgs.repos.vscode.vscode-marketplace-release.ms-python.autopep8; # 仅补市场有
      profiles = [ "python" ];
      client = true;
      server = true;
    }

    # --- go profile ---
    {
      id = "golang.Go";
      pkg = pkgs: pkgs.vscode-extensions.golang.go;
      profiles = [ "go" ];
      client = true;
      server = true;
    }
    {
      id = "bufbuild.vscode-buf";
      pkg = pkgs: pkgs.repos.vscode.vscode-marketplace-release.bufbuild.vscode-buf; # 仅补市场有
      profiles = [ "go" ];
      client = true;
      server = true;
    }
  ];
}
