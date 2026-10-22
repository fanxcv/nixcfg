<!-- project-rules:START -->
# Project Rules —— 业务编码规范

## 0. 最小化验证（强制，先读此条）

> 改毕只验所及。全量验证须用户明确同意方可跑；未获同意即禁止，子代理同受此约束。纯文案、注释、文档、字面量配置改动，通常零验证。

- 验惟所及：受影响单测、单文件编译或类型检查、一条最小复现命令，验毕即止
- 禁默认全量：全仓 test / build / lint、整套集成与 e2e，不以「稳妥」「保险」为由自跑
- 确需全量先申请：说明跑什么、为何非全量不可、约耗几时；得明确同意方可执行
- 影响面不明取最窄一条先跑，一次只扩一级并言明缘由
- 新写测试亦取最小：一处能拦住该改动的断言即可，不铺用例矩阵
- 例外（不须申请）：项目既定门禁（git hooks / CI 明定者）；安全、鉴权、凭据、数据迁移、不可逆操作相关改动

本项目命令：

- 改毕默认跑（最窄一条）：`<填本项目最窄验证命令>`
- 全量门禁（须用户同意方跑）：`<填全仓测试/构建命令>`

## 1. 代码简洁性

- 务简：零冗余、不留虚设
- 重复三见必提为公共组件/工具
- 注释非必要不立；禁留注释块、无人跟进的 TODO、dead code
- 函数贵小：一职一事，滚动多屏方读毕者即拆
- 单文件宜小（约 1200 行内；测试与生成代码除外），逾则按职责拆
- 禁过度设计：不为臆想之需添抽象层

## 2. 命名规范

- 函数/方法：动词起首，述其所为
- 变量：义必明；禁 `temp`/`data`/`info`/`result`/`obj`/`item`（极短 lambda 中除外）
- 常量、类型、文件名：随本项目语言与既有代码惯式（大小写风格各从其俗，勿另立）
- 文件名：与主要导出对应
- 缩写：约定俗成者允（`ctx`/`cfg`/`err`/`req`/`resp`/`db`/`mq`），自创者禁

## 3. 错误处理

- 禁吞错：catch/ignore 而不理，非有注释明因即为缺陷
- 错必带上下文：谁、何事、败于何
- 库/共享代码不抛未受检异常、不 panic，惟按本项目语言惯式返回错误任调用方裁
- 对外接口错：有据可依的错误标识 + 人可解之消息
- 日志与返回分离：日志为排查，返回为调用方处理，两不相涉

## 4. 安全编码

- 参数化查询：禁字符串拼接 SQL，必用参数绑定
- 输入校验：外部输入（HTTP 参数、消息体、文件）必验类型、长度、范围
- 禁硬编码密钥：token、密码、AK/SK 走配置文件或环境变量
- 敏感数据脱敏：密码、token、身份证号禁入日志

## 5. 幂等性（有写接口/消息消费/定时任务者适用）

- 查询必无副作用；写接口、消息/CDC 消费、定时任务必显式处理重复请求
- 重复提交结果必可控：不得重复落库、重复推送、重复触发外部副作用
- 幂等策略：先业务唯一键/请求幂等键，禁依赖自增 ID 或进程内状态判断重复

## 6. 针对性改动

- 惟改需求所及，严禁波及现有功能
- 改前先明旧逻辑，不确则问
- 新增功能不得更动既有接口行为语义

## 7. 测试与提交

- 改代码即担责：交差前必跑第 0 节所定的最小验证，不过不交
- 新增或修复逻辑必留一处可运行的验证（测试或最小自检），禁无验交付
- 修 bug 先求根因：查全部调用方，于共用处一次修净，勿逐点补丁
- 提交一事一改，信息格式随本项目历史惯例（无惯例则 `scope: 简述`）；不夹带无关改动、不提交生成物与凭据
- 禁自动 push 远端；force push、reset --hard、删分支等不可逆操作先报后动
<!-- project-rules:END -->

<!-- project-db:START -->
## 数据库与文档目录

### 数据库操作

- 数据库变更经项目既定通道：有 DB MCP 则走 MCP，有迁移工具（golang-migrate、Alembic、Liquibase、Flyway 等）则走迁移脚本
- 禁 Bash 直执数据库命令（mysql/psql/mongo）
- 禁临时脚本操库（Python/Node 手搓连接同禁）
- 生产库写操作：先询用户，先留退路（备份/快照/事务），后动手
- 变更必留 SQL 脚本存档：`docs/sql/YYYYMMDD_功能.sql`
  ```sql
  -- 日期: YYYY-MM-DD
  -- 功能: 描述
  ```

### 文档目录

- `docs/` 正式文档
- `reference/` 临时/参考文档
<!-- project-db:END -->

# 项目规则（AI 协作约定）

## 核心原则：配置即 nix 声明

仓库里的一切由 nix 声明：软件、设置、服务、密钥都写在 nix 模块里，改配置就是改 nix。
（2026-09 移除旧的 `wanted.yaml` 意图清单机制：不再维护「清单 ↔ nix 双向同步」，勿再引入。）

## 验证目标选择（按变更影响面，不全量 eval）

| 变更文件范围 | 验证目标 |
|---|---|
| hosts/_darwin_/、home/fan/_darwin_/、users/fan、hosts/<mac机>/、home/fan/<mac机>/ | darwinConfigurations（改共享层 → 三台；改机器专属 → 仅该机器） |
| home/fan/_common_/、home/fan/default.nix | darwinConfigurations + homeConfigurations（跨平台共享层，两边都受影响） |
| home/fan/_linux_/、_ubuntu_/、_container_/、_nixos_/、_alpine_/、ide-si/、ide-lenovo/、ide-mac/ | homeConfigurations（ide-si / ide-lenovo / ide-mac） |
| hosts/_nixos_/ | nixosConfigurations（nix-lenovo / nix-asus） |
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
- **系统域 secrets**（NixOS host keys 等）：走 agenix 系统层（hosts/ 下声明，root 激活解密）。
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

- [ ] 镜像/缓存配置（tools/config.nix 的 substituters/cachix/公钥）改动后：同步 flake.nix nixConfig、docker/ide/ubuntu/Dockerfile、docker/ide/ubuntu/entrypoint.sh 与 pve/deploy.sh，并跑 `nix flake check`（tests/mirror-consistency.py 断言四处全等 + PVE 层子集一致）
- [ ] 改 nix 模块后：eval 变更影响的配置目标（见「验证目标选择」）
- [ ] 机器专属新增：对应目录建模块（tools.scan 自动导入）+ flake.nix 注册
- [ ] 密钥类文件（secrets/*.age）必须入库 git（flake 的 self 只打包已跟踪文件）
