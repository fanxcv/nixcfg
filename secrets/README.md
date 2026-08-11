# secrets/ —— agenix 加密 secrets

密钥用 age 加密入库（.age 文件可提交 git），激活时由 home-manager 的 agenix
模块自动解密到目标路径。明文只存在于：加密时的源文件 + 解密后的目标路径。

## 密钥对

- 私钥：`$HOME/.secrets/age-keys.txt`（chmod 600，**永不提交 git**）
  - 容器场景：compose 已挂载 `~/.secrets → /root/.secrets`（宿主机），容器重建不丢
  - 新增机器：把私钥拷到该机 `$HOME/.secrets/age-keys.txt`，公钥加入 `keys.nix`
- 公钥：`age-keygen -y ~/.secrets/age-keys.txt`
- 当前接收者见 `keys.nix`（本仓库当前仅一台 ide 容器）

## 加密新文件

```bash
# 单接收者（-r 用 keys.nix 里的公钥）
age -e -r age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204 \
    -o secrets/ai.env.age /root/.secrets/ai.env

# 多接收者（从 keys.nix 批量取）
age -e -R <(nix eval --raw .#homeConfigurations."fan@ide".config.home.homeDirectory 2>/dev/null) \
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

## 启用（home-manager 侧）

1. 加密文件就位（上面的命令，目标路径与 secrets.nix 中声明一致）
2. `home/fan/_common_/secrets.nix` 取消 agenix 注释块（imports + age.* 两处）
3. 私钥就位：`$HOME/.secrets/age-keys.txt`
4. 容器内 `nix run .#ide` 重新激活验证

## 轮换私钥

```bash
age-keygen -o ~/.secrets/age-keys.txt.new && chmod 600 ~/.secrets/age-keys.txt.new
# 旧私钥解出所有 .age → 新公钥重新加密 → 更新 keys.nix → 替换私钥
```
