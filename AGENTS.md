# 项目规则（AI 协作约定）

## 核心原则：wanted.yaml 是唯一事实来源

`wanted.yaml`（仓库根）是用户对软件与配置的**意图清单**，Nix 配置是它的**实现**。
两者必须时刻一致——**任何一方变更都要同步到另一方**，不允许只改一边。

## 双向同步规则

### 1. wanted.yaml 变更 → Nix（用户改了清单）

1. 检测变更：`git diff wanted.yaml`（找出增/删/改的行）
2. 解析：新增条目 = 安装/启用；删除条目 = 卸载/移除；改值 = 更新配置
3. 翻译成 Nix：更新对应模块（映射表见下），用户行尾注释原样保留
4. 验证：**eval 变更影响到的配置目标**（见下方"验证目标选择"），
   wanted.yaml 用 `python3 -c "import yaml; yaml.safe_load(open('wanted.yaml'))"` 校验语法
5. 回填：确认条目与 Nix 一致后向用户汇报变更清单

### 2. Nix 变更 → wanted.yaml（改了配置仓库）

每次修改仓库 nix 文件（新增/删除模块、软件、设置、服务、密钥、平台层改动）后，
**必须**同步更新 wanted.yaml 对应区段：

- 删除软件/配置 → wanted.yaml 对应条目一并删除（含相关残留配置引用）
- 新增/修改 → 按 wanted.yaml 格式（`- 名称 # 备注` / `键: 值 # 备注`）同步填写
- 平台/机器层结构变化（新增机器区段、模块目录调整）→ wanted.yaml 对应区段同步调整

顺序要求：**先同步 wanted.yaml，再跑 eval 验证**，提交前检查
`git diff wanted.yaml` 与本次 Nix 改动匹配。

## 验证目标选择（按变更影响面，不全量 eval）

| 变更文件范围 | 验证目标 |
|---|---|
| hosts/_darwin_/、home/fan/_darwin_/、users/fan、hosts/<mac机>/、home/fan/<mac机>/ | darwinConfigurations（改共享层 → 三台；改机器专属 → 仅该机器） |
| home/fan/_common_/、home/fan/default.nix | darwinConfigurations + homeConfigurations（跨平台共享层，两边都受影响） |
| home/fan/_linux_/、_ubuntu_/、_container_/、_nixos_/、_alpine_/、ide-si/、ide-lenovo/ | homeConfigurations（ide-si / ide-lenovo） |
| hosts/_nixos_/ | nixosConfigurations（当前未接入真机，暂无目标） |
| secrets/、flake.nix、AGENTS.md、wanted.yaml | 按实际影响面判断；不确定时跑受影响平台的 eval |

## 区段映射表（wanted.yaml 层次 = 代码目录，2026-08 重组）

| wanted.yaml 区段 | Nix 位置 |
|---|---|
| common.pkgs | home/fan/_common_/base.nix、modules/home/{tmux,ai,codex,pi}.nix |
| common.git / zsh / tmux / codex / pi / mise / ai / ssh | home/fan/_common_/（base.nix、shells.nix）、modules/home/*.nix（git 含 credential.helper=store） |
| common.mirrors | home/fan/_common_/mirrors.nix、tools/config.nix（useChinaMirror/githubProxy 唯一入口） |
| common.nix | flake.nix nixConfig、modules/darwin/nix.nix、hosts/nix-pve、docker/ide/ubuntu/Dockerfile（4 处一致） |
| common.vscode | modules/home/vscode.nix（包源/扩展/设置） |
| common.secrets | home/fan/_common_/secrets.nix、secrets/ |
| macos.system.apps | hosts/_darwin_/base/apps.nix |
| macos.system.formulae / brew_mirror | hosts/_darwin_/base/homebrew.nix |
| macos.system.settings | hosts/_darwin_/gui/desktop/quartz/*.nix、gui/display/*.nix（loginwindow）、kernel/*.nix |
| macos.system.dns | hosts/_darwin_/base/networking.nix |
| macos.system.services | home/fan/_darwin_/syncthing.nix（hosts/_darwin_/services/ 为空占位） |
| macos.system.fonts | hosts/_darwin_/i18n/fonts.nix |
| macos.system.locale | hosts/_darwin_/i18n/locale.nix |
| macos.user.hm_launchd_fix | home/fan/_darwin_/launchd-fix.nix |
| macos.user.apps | home/fan/_darwin_/gui/apps/*.nix（orbstack/clash-verge/edge/tailscale）、hosts/_darwin_/base/{rustdesk,edge-policy,edge-updater}.nix |
| macos.user.secrets | home/fan/_darwin_/tailscale.nix、secrets/ |
| macos.machines.<机> | hosts/<机>/*.nix、home/fan/<机>/*.nix |
| linux.common | home/fan/_linux_/ |
| linux.ubuntu | home/fan/_ubuntu_/ |
| linux.alpine | home/fan/_alpine_/ |
| linux.container | home/fan/_container_/ |
| linux.container.machines.ide-si / ide-lenovo | home/fan/ide-si/、home/fan/ide-lenovo/（mise 共享 _container_/mise.nix，hostName 分支差异） |
| nixos.nix-pve | hosts/nix-pve/、home/fan/nix-pve/ |
| pve.common | pve/default.nix、pve/apply.sh |
| pve.machines.<机> | pve/<机>/、home/fan/<机>/、home/fan/_pve_/ |
| 自建模块库（modules/）、本地包（packages/）、unstable/vscode 市场（overlays/） | modules/home/vscode.nix（vscode 封装：包源/扩展/设置）、modules/darwin/nix.nix（darwin nix 配置）、packages/default.nix、overlays/unstable.nix、overlays/vscode.nix；flake.nix（unstable input 锁 rev，周级 nix flake update） |

## 架构约定（2025-08 整理，新增/修改模块必须遵守）

### secrets 架构（无兑底链，单一机制）

- **fan 域 secrets**（ai-env / git-credentials / tailscale authkey / ssh 私钥 / keystore / skemate 配置）：
  统一由 `home.activation` 解密——`${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" -o <目标> <secrets/*.age>`，
  模式见 home/fan/_common_/secrets.nix 与各模块。**失败即部署失败**（无 if 无 || true）。
- **系统域 secrets**（NixOS host keys、nix-pve comin 等）：走 agenix 系统层（hosts/ 下声明，root 激活解密）。
- **禁止**：HM 层 age.secrets 声明（agenix homeManagerModules 已整体移除）、
  agenixContainerFallback 类兑底链、条件跳过解密。
- 密钥维护：明文放 secrets/source/ → `./secrets/encrypt.sh` 生成 .age（git 可公开），私钥 `$HOME/.secrets/age-keys.txt`。

### 激活脚本规范

- **系统工具**（sudo/launchctl/pkill/open/pgrep/sleep/cat/find/readlink）：裸命令即可——
  activatePathFix（home/fan/_common_/path.nix）已把系统 PATH 追加进 HM 激活环境，无需绝对路径 local。
- **nix 工具**（python3/age/git/curl/gnused/...）：必须 `${pkgs.xxx}/bin/xxx` 绝对路径（不在系统 PATH）。
- **失败策略**：
  - 禁止静默吞错（`2>/dev/null` 后无输出无处理）；
  - `|| true` 只允许幂等检查（服务未注册/文件不存在等预期失败），必须注释原因；
  - 非关键失败 → 显式 `echo "警告: ..."`（部署继续）；
  - 前置步骤失败导致当前步骤无法进行 → 当前步骤直接失败（exit 1，部署中止，暴露问题）。
- **root 操作归系统层**：涉及 root 域/LaunchDaemon/跨用户进程的操作放 system.activationScripts
  （root 直跑，无 sudo 桥接）——例：RustDesk 注入（hosts/_darwin_/base/rustdesk.nix）。
- **变量引用**：`$var` 后紧跟全角标点（，。）会被 bash 按 UTF-8 字节吸进变量名（isalnum locale 陷阱）→
  unbound variable；必须加空格（`$var ，跳过`）。

## 强制动作清单

- [ ] 改 nix 模块后：同步 wanted.yaml（先）→ eval 变更影响的配置目标（后）
- [ ] wanted.yaml 语法校验（yaml.safe_load）
- [ ] 机器专属新增：wanted.yaml 加 `<机器名>:` 区段 + 对应目录建模块（tools.scan 自动导入）
- [ ] 提交前核对 `git diff wanted.yaml` 与 nix 改动一致
- [ ] 密钥类文件（secrets/*.age）必须入库 git（flake 的 self 只打包已跟踪文件）
