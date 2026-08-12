# secrets/ —— agenix 加密 secrets

密钥用 age 加密入库（.age 文件可提交 git），激活时由 home-manager 的 agenix
模块自动解密到目标路径。明文只存在于：加密时的源文件 + 解密后的目标路径。
**已启用**：secrets.nix 的 agenix 块处于激活状态，激活时自动解密 ai.env →
~/.secrets/ai.env、git-credentials → ~/.git-credentials。

## 密钥对

- 私钥：`$HOME/.secrets/age-keys.txt`（chmod 600，**永不提交 git**）
  - 容器场景：compose 挂载 `./.secrets → /root/.secrets`（docker/ide/ 目录下，随仓库走）
    ——把 age-keys.txt 放进 docker/ide/.secrets/ 即可，容器重建不丢
  - 新增机器：把私钥拷到该机 `$HOME/.secrets/age-keys.txt`，公钥加入 `keys.nix`
- 公钥：`age-keygen -y ~/.secrets/age-keys.txt`
- 当前接收者见 `keys.nix`（本仓库当前仅一台 ide 容器）

## 加密新文件

明文统一放 `source/`（已 gitignore），一键批量加密，接收者自动取 `keys.nix` 全部公钥：

```bash
./encrypt.sh           # 加密 source/ 下所有文件 → secrets/<同名>.age
./encrypt.sh --force   # 覆盖已存在的 .age
```

例：git 凭据也走这套加密（`git-credentials.age` 位置与 secrets.nix 预留一致）：

```bash
cp ~/.secrets/git-credentials source/git-credentials
./encrypt.sh           # → secrets/git-credentials.age，激活时解密到 ~/.git-credentials
```

单文件手写命令等价形式：

```bash
# 单接收者（-r 用 keys.nix 里的公钥）
age -e -r age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204 \
    -o secrets/ai.env.age /root/.secrets/ai.env

# 多接收者（从 keys.nix 批量取）
age -e -R <(nix eval --raw .#homeConfigurations."fan@ide-si11".config.home.homeDirectory 2>/dev/null) \
    -o secrets/xxx.age <明文源>
```

## 解密查看 / 更新

```bash
# 解密到 stdout（不落盘）
age -d -i ~/.secrets/age-keys.txt secrets/ai.env.age

# 更新：解密到临时文件 → 改 → 重新加密 → 删临时文件
age -d -i ~/.secrets/age-keys.txt -o /tmp/ai.env secrets/ai.env.age
# ...编辑 /tmp/ai.env...
age -e -r age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204 \
    -o secrets/ai.env.age /tmp/ai.env && rm /tmp/ai.env
```

## 启用（home-manager 侧）——当前状态：

1. ✅ 加密文件就位：secrets/ai.env.age、secrets/git-credentials.age（git 已跟踪）
2. ✅ `home/fan/_common_/secrets.nix` agenix 块已启用（imports + age.* 已取消注释）
3. ⚠️ 私钥就位：`docker/ide/.secrets/age-keys.txt`（容器内 /root/.secrets/age-keys.txt）
   ——每个新部署的容器都要放；缺失会导致激活失败（agenix 不解密即报错）
4. 容器内 `nix run .#ide-si11`（lenovo 用 `.#ide-lenovo`）重新激活验证

## RustDesk 机器身份（所有 Mac）

RustDesk.toml 含每台机器的 ID 密钥对，**必须各机独立**（共享会导致 ID 冲突）：

```bash
# 每台 Mac 各自执行：
age -d -i ~/.secrets/age-keys.txt -o /tmp/rustdesk.toml \
    <该机已有的 .age 或从本机配置复制>
# 编辑/确认后：
age -e -R <(grep -oE 'age1[a-z0-9]{50,}' keys.nix | sort -u) \
    -o secrets/rustdesk.toml.<hostName>.age /tmp/rustdesk.toml && rm /tmp/rustdesk.toml
```

命名约定：`rustdesk.toml.<hostName>.age`（如 rustdesk.toml.mini-m4.age），
解密逻辑在 `hosts/_darwin_/base/rustdesk.nix`（按机器自动选择文件，缺失则跳过）。
文件必须提交 git（flake 的 self 只打包已跟踪文件）。

## 轮换私钥

```bash
age-keygen -o ~/.secrets/age-keys.txt.new && chmod 600 ~/.secrets/age-keys.txt.new
# 旧私钥解出所有 .age → 新公钥重新加密 → 更新 keys.nix → 替换私钥
```
