# VSCode 封装模块（tsln1998/nixcfg 思路：hm 内置 programs.vscode 之上统一包源/市场/设置）
# 清单/设置以 docs/tsln-vscode.yaml 为准（用户维护该文件，调整后同步本模块）
# 启用方式（平台层）：
#   mac：vscode.enable = true            → package 默认 null，用商店版 App，扩展/设置由 nix 锁定
#   nixos：vscode.enable = true; vscode.package = pkgs.repos.unstable.vscode
# 扩展主市场 pkgs.repos.unstable.vscode-extensions（unstable 通道，扩展版本较新）；
#   补市场 pkgs.repos.vscode.vscode-marketplace-release 仅给 nixpkgs 缺失的扩展（autopep8 / vscode-buf）
# 语言 profile：vscode --profile python / --profile go 启动，独立扩展+设置（公共部分自动并入）
{ config, lib, pkgs, ... }:
let
  cfg = config.vscode;
  market = pkgs.repos.unstable.vscode-extensions;
  # 补市场（marketplace-release）：eval 时 IFD 拉取扩展清单（nix 2.18+ 默认允许），启用 vscode 的平台才会触发
  release = pkgs.repos.vscode.vscode-marketplace-release;

  # 公共扩展（docs/tsln-vscode.yaml extensions.base）
  baseCommonExtensions = [
    # 中文语言包
    market.ms-ceintl.vscode-language-pack-zh-hans
    # 主题/图标
    market.github.github-vscode-theme
    market.pkief.material-icon-theme
    market.miguelsolorio.fluent-icons
    # 高亮
    market.oderwat.indent-rainbow
    # Git
    market.codezombiech.gitignore
    market.waderyan.gitblame
    market.mhutchie.git-graph
    # Nix / direnv
    market.jnoortheen.nix-ide
    market.mkhl.direnv
    # 通用
    market.editorconfig.editorconfig
    market.gruntfuggly.todo-tree
    market.tamasfe.even-better-toml
    market.redhat.vscode-yaml
    market.usernamehw.errorlens
    market.humao.rest-client
    market.yzhang.markdown-all-in-one
  ];
  # 仅客户端 UI 类扩展（base 公共，但 server 端不装：remote-ssh 是客户端侧远程连接器）
  clientOnlyExtensions = [
    market.ms-vscode-remote.remote-ssh
  ];
  # 客户端扩展（default profile）＝公共 18 个
  baseExtensions = baseCommonExtensions ++ clientOnlyExtensions;

  # 公共设置（docs/tsln-vscode.yaml settings，mac/nixos 通用部分）
  baseSettings = {
    "chat.disableAIFeatures" = true;

    "window.commandCenter" = false;
    "window.autoDetectColorScheme" = false;
    "window.openFilesInNewWindow" = "off";
    "window.openFoldersInNewWindow" = "on";
    "window.title" = "\${rootName}\${separator}\${appName}";

    "workbench.startupEditor" = "none";
    "workbench.editor.useModal" = "off";
    "workbench.settings.editor" = "json";
    "workbench.iconTheme" = "material-icon-theme";
    "workbench.productIconTheme" = "fluent-icons";
    "workbench.preferredLightColorTheme" = "GitHub Light";
    "workbench.preferredDarkColorTheme" = "GitHub Dark";

    "files.autoSaveWhenNoErrors" = true;
    "files.autoSaveWorkspaceFilesOnly" = true;
    "files.eol" = "\n";
    "files.enableTrash" = false;

    "editor.fontLigatures" = true;
    "editor.cursorSmoothCaretAnimation" = "on";
    "editor.cursorBlinking" = "phase";
    "editor.inlineSuggest.enabled" = true;
    "editor.acceptSuggestionOnCommitCharacter" = false;
    "editor.guides.bracketPairs" = true;
    "editor.formatOnSave" = false;
    "editor.largeFileOptimizations" = false;
    "editor.inlineSuggest.showToolbar" = "always";
    "editor.minimap.autohide" = "scroll";

    "terminal.integrated.cursorStyle" = "line";
    "terminal.integrated.cursorStyleInactive" = "underline";

    "explorer.autoReveal" = true;
    "explorer.autoRevealExclude" = {
      "**/node_modules" = true;
    };

    "git.autofetch" = true;
    "git.fetchOnPull" = true;
    "git.enableSmartCommit" = true;

    "gitblame.delayBlame" = 500;
    "gitblame.ignoreWhitespace" = true;

    # nix-ide 语言服务（nixd/nixfmt 需在 PATH，需要时加 home.packages）
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "nixd";
    "nix.formatterPath" = "nixfmt";

    "security.workspace.trust.enabled" = false;

    "redhat.telemetry.enabled" = false;

    "update.showReleaseNotes" = false;
  };

  # 语言扩展（docs/tsln-vscode.yaml extensions.profiles；server 端无 profile 概念，扩展平铺）
  pythonExtensions = [
    market.ms-python.python
    market.ms-python.debugpy
    market.ms-python.isort
    market.ms-python.vscode-pylance
    release.ms-python.autopep8 # 仅补市场有
  ];
  goExtensions = [
    market.golang.go
    release.bufbuild.vscode-buf # 仅补市场有
  ];

  # 语言 profile 生成（tsln _vsc_profile_ 思路：公共 + 语言专属，独立完整配置）
  # 注意：enableUpdateCheck / enableExtensionUpdateCheck 仅 default profile 有效（hm 限制）
  profile =
    p:
    {
      extensions = baseExtensions ++ (p.extensions or [ ]);
      userSettings = baseSettings // (p.userSettings or { });
    };

  # vscode-server 扩展集合（容器远程开发）：公共（不含客户端 UI 类）+ 语言扩展平铺
  # 主题/图标类扩展 server 端无 UI 意义，但保留可避免两份清单；remote-ssh 等客户端扩展不装 server 端
  serverExtensions = baseCommonExtensions ++ pythonExtensions ++ goExtensions;
in
{
  options.vscode = {
    enable = lib.mkEnableOption "VSCode（扩展/设置由 nix 声明）";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null; # null = 不装 nix 包（mac 商店版）；nixos 平台层设为 unstable.vscode
      description = "vscode 包本体；null 时不安装（商店版场景）。";
    };
    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "平台层追加扩展（如 mac 的 remote-ssh）。";
    };
    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "平台层追加设置（如 nixos 的 titleBarStyle）。";
    };
    server = {
      enable = lib.mkEnableOption "vscode-server 扩展管理（容器远程开发：~/.vscode-server/extensions 链接到 nix store）";
      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "vscode-server 追加扩展（平台层）。";
      };
    };
  };

  config = lib.mkMerge [
    # 客户端（vscode.enable）：mac/nixos 平台层启用
    (lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      package = cfg.package;
      mutableExtensionsDir = false; # 扩展由 nix 锁定，编辑器内不可增删
      profiles = {
        default =
          (profile {
            extensions = cfg.extensions;
            userSettings = cfg.settings;
          })
          // {
            # 键位：仅 cmd/ctrl+d → 删除当前行（editor.action.deleteLines）；其余全部默认
            # 平台分支：mac=cmd+d，linux=ctrl+d（VSCode 键位不含平台自动映射，需显式声明）；
            # 放 profiles.default 而非顶层：顶层旧选项名会触发 HM rename，未启用 vscode 的平台报错
            keybindings = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
              { key = "cmd+d"; command = "editor.action.deleteLines"; }
            ] ++ lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
              { key = "ctrl+d"; command = "editor.action.deleteLines"; }
            ];
            enableUpdateCheck = false;
            enableExtensionUpdateCheck = false;
          };
        # 语言 profile（docs/tsln-vscode.yaml extensions.profiles，vscode --profile <名> 启动）
        python = profile {
          extensions = pythonExtensions;
        };
        go = profile {
          extensions = goExtensions;
          userSettings = {
            "go.showWelcome" = false;
            "go.diagnostic.vulncheck" = "Off";
          };
        };
      };
    };
    })

    # vscode-server（容器远程开发）：独立于 vscode.enable——容器只开 server 不开客户端
    # （vscode-server.nix 仅设 server.enable = true；若挂在 cfg.enable 下链接永远不会生成）
    (lib.mkIf cfg.server.enable {
      home.file.".vscode-server/extensions" = {
        source = pkgs.buildEnv {
          name = "vscode-server-extensions";
          paths = serverExtensions ++ cfg.server.extensions;
          pathsToLink = [ "/share/vscode/extensions" ];
          postBuild = ''
            ln -s $out/share/vscode/extensions/* $out/ 2>/dev/null || true
            rm -rf $out/share
          '';
        };
        recursive = true;
      };
      # 清掉客户端手装的旧扩展目录（nix 接管后目录只读；不清理时 ln 会失败）
      home.activation.vscodeServerExtensions = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
        if [ -d "$HOME/.vscode-server/extensions" ] && [ ! -L "$HOME/.vscode-server/extensions" ]; then
          rm -rf "$HOME/.vscode-server/extensions"
        fi
      '';
    })
  ];
}
