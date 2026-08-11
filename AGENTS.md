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
- `current_state` 区段（实机对照）在状态变化时更新
- 平台/机器层结构变化（新增机器区段、模块目录调整）→ wanted.yaml 对应区段同步调整

顺序要求：**先同步 wanted.yaml，再跑 eval 验证**，提交前检查
`git diff wanted.yaml` 与本次 Nix 改动匹配。

## 验证目标选择（按变更影响面，不全量 eval）

| 变更文件范围 | 验证目标 |
|---|---|
| hosts/_darwin_/、home/fan/_darwin_/、users/fan、hosts/<mac机>/、home/fan/<mac机>/ | darwinConfigurations（改共享层 → 三台；改机器专属 → 仅该机器） |
| home/fan/_common_/、home/fan/default.nix | darwinConfigurations + homeConfigurations（跨平台共享层，两边都受影响） |
| home/fan/_linux_/、_nixos_/、_alpine_/、ide/ | homeConfigurations（ide / ide-global） |
| hosts/_nixos_/ | nixosConfigurations（当前未接入真机，暂无目标） |
| secrets/、flake.nix、AGENTS.md、wanted.yaml | 按实际影响面判断；不确定时跑受影响平台的 eval |

## 区段映射表

| wanted.yaml 区段 | Nix 位置 |
|---|---|
| global.pkgs | home/fan/_common_/base.nix、ai.nix、claude.nix、codex.nix、pi.nix |
| global.app_configs | home/fan/_common_/（base.nix、shells.nix、tmux.nix、codex.nix、claude.nix、pi.nix、mise.nix） |
| global.secrets | home/fan/_common_/secrets.nix、secrets/ |
| macos.all_macs.apps | hosts/_darwin_/base/apps.nix |
| macos.all_macs.formulae | hosts/_darwin_/base/homebrew.nix |
| macos.all_macs.settings | hosts/_darwin_/gui/desktop/quartz/*.nix、gui/display/*.nix、kernel/*.nix |
| macos.all_macs.services | hosts/_darwin_/services/*.nix |
| macos.all_macs.fonts | hosts/_darwin_/i18n/fonts.nix |
| macos.all_macs.locale | hosts/_darwin_/i18n/locale.nix |
| macos.all_macs.user_pkgs | home/fan/_common_/*.nix |
| macos.all_macs.app_configs | home/fan/_darwin_/gui/apps/*.nix、home/fan/_common_/*.nix |
| macos.all_macs.secrets | hosts/_common_/base/agenix.nix、hosts/_darwin_/base/rustdesk.nix、secrets/ |
| macos.mini_m4 | hosts/mini-m4/*.nix、home/fan/mini-m4/*.nix |
| linux.ide | home/fan/_linux_/、home/fan/_nixos_/、home/fan/_alpine_/、home/fan/ide/ |
| nixos.pending | hosts/_nixos_/ |

## 强制动作清单

- [ ] 改 nix 模块后：同步 wanted.yaml（先）→ eval 变更影响的配置目标（后）
- [ ] wanted.yaml 语法校验（yaml.safe_load）
- [ ] 机器专属新增：wanted.yaml 加 `<机器名>:` 区段 + 对应目录建模块（tools.scan 自动导入）
- [ ] 提交前核对 `git diff wanted.yaml` 与 nix 改动一致
- [ ] 密钥类文件（secrets/*.age）必须入库 git（flake 的 self 只打包已跟踪文件）
- [ ] 未声明但实机存在的软件，记录到 wanted.yaml 的 current_state 区段（不擅自声明）
