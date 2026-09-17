# 项目规则（AI 协作约定）

## 核心原则：配置即 nix 声明

仓库里的一切由 nix 声明：软件、设置、服务、密钥都写在 nix 模块里，改配置就是改 nix。
（2026-09 移除旧的 `wanted.yaml` 意图清单机制：不再维护「清单 ↔ nix 双向同步」，勿再引入。）

## 验证目标选择（按变更影响面，不全量 eval）

| 变更文件范围 | 验证目标 |
|---|---|
| hosts/_darwin_/、home/fan/_darwin_/、users/fan、hosts/<mac机>/、home/fan/<mac机>/ | darwinConfigurations（改共享层 → 三台；改机器专属 → 仅该机器） |
| home/fan/_common_/、home/fan/default.nix | darwinConfigurations + homeConfigurations（跨平台共享层，两边都受影响） |
| home/fan/_linux_/、_ubuntu_/、_container_/、_nixos_/、_alpine_/、ide-si/、ide-lenovo/ | homeConfigurations（ide-si / ide-lenovo） |
| hosts/_nixos_/ | nixosConfigurations（当前未接入真机，暂无目标） |
| secrets/、flake.nix、AGENTS.md | 按实际影响面判断；不确定时跑受影响平台的 eval |

## 架构约定（2025-08 整理，新增/修改模块必须遵守）

### 目录扫描（tools.scan）规范

- **scan 目录内禁止放置需要 import 传参的模块**：隐式导入即 `import <dir>` 到 default.nix，模块无法在 import 时传参，只能吃 specialArgs 全局注入（self/inputs/outputs/tools/useChinaMirror/hostName/isContainer/platform）。需要参数的模块一律用显式 `imports` 列表组装（如 hosts/<机>/default.nix、module-list.nix）。
- **无 default.nix 的嵌套目录被整目录静默跳过**：scan 只导入「直接子 .nix 文件」或「含 default.nix 的子目录」，不含 default.nix 的子目录里埋的 .nix 一律不生效，且不报错。勿在 scan 目录里埋无 default.nix 的嵌套 layer；要生效就给它补 default.nix 或用显式 imports。
- **import 顺序 = 字典序（builtins.readDir + attrNames）**：模块间如依赖顺序（lib.mkOrder / 覆盖等）请用显式 imports 保证，勿依赖 scan 的字典序。
- 验证：`nix flake check`（含 tests/mirror-consistency.py 镜像一致性断言，见下方强制动作清单）。

### secrets 架构（无兑底链，单一机制）

- **fan 域 secrets**（ai-env / git-credentials / tailscale authkey / ssh 私钥 / keystore / skemate 配置）：
  统一由 `home.activation` 解密——`${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" -o <目标> <secrets/*.age>`，
  模式见 home/fan/_common_/secrets.nix 与各模块。**失败即部署失败**（无 if 无 || true）。
- **系统域 secrets**（NixOS host keys、nix-pve comin 等）：走 agenix 系统层（hosts/ 下声明，root 激活解密）。
- **禁止**：HM 层 age.secrets 声明（agenix homeManagerModules 已整体移除）、
  agenixContainerFallback 类兑底链、条件跳过解密。
- 密钥维护：明文放 secrets/source/ → `./secrets/encrypt.sh` 生成 .age（git 可公开），私钥 `$HOME/.secrets/age-keys.txt`。
- **命名与位置规则**（secrets/README.md 规约）：
  - 公共/多机共享 → `secrets/<name>.age`（根）；机器独有 → `secrets/hosts/<machine>/<name>.age`（一个机器一个目录，不只放密钥：skemate 配置、lucky 归档、tailscale state 等一切机器独有物都进这里）。
  - 跨机器共用而非常见文件：文件本体放主机器目录，其他机器跨引用并注释说明。
  - 公钥 `<key>.pub` 明文直接入库（不加密、不入 source/、encrypt.sh 自动跳过）；私钥/敏感物一律 `.age` 加密入库。
  - 消费方 nix 引用路径：`${../../..}/secrets/hosts/<machine>/<name>.age`（相对 home/fan/<machine>/ 的仓库根）。
  - 新机器：keys.nix 加 age 公钥 + secrets/hosts/<machine>/ 建目录（encrypt.sh 自动保持 source/ 子目录结构）。

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

- [ ] 镜像/缓存配置（tools/config.nix 的 substituters/cachix/公钥）改动后：同步 flake.nix nixConfig 与 docker/ide/ubuntu/Dockerfile，并跑 `nix flake check`（tests/mirror-consistency.py 断言三方一致）
- [ ] 改 nix 模块后：eval 变更影响的配置目标（见「验证目标选择」）
- [ ] 机器专属新增：对应目录建模块（tools.scan 自动导入）+ flake.nix 注册
- [ ] 密钥类文件（secrets/*.age）必须入库 git（flake 的 self 只打包已跟踪文件）
