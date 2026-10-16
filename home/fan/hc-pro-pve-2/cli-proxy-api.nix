# cli-proxy-api（docker compose，声明由 nix 渲染派发）
# 参考：ali-ai /opt/cli-proxy/（同镜像 eceasy/cli-proxy-api-plus，:4321）
# 容器运行时仍 docker（B 路线）；compose 由 nix 生成，config.yaml 仅首装时补（age 加密，含 secret-key）
# auth-dir（账号 token）/logs/static 是状态，不归 nix（static 面板页由服务自 panel-github-repository 下载）
# 更新流：改本文件 → 部署 → activation 补 compose、config 缺失时才补 → docker compose up -d 重建
# config.yaml 首装后归用户维护（改 secrets 后需手动 cp 覆盖，nix 不再自动覆盖）

{
  lib,
  pkgs,
  ...
}:
let
  composeYaml = pkgs.writeText "cli-proxy-compose.yml" ''
    networks:
      fan:
        external: true

    services:
      cli-proxy-api:
        image: eceasy/cli-proxy-api
        container_name: cli-proxy-api
        restart: always
        volumes:
          - ./auth-dir:/root/.cli-proxy-api
          - ./config.yaml:/CLIProxyAPI/config.yaml
          - ./static:/CLIProxyAPI/static
          - ./logs:/CLIProxyAPI/logs
        ports:
          - 4321:4321
        networks:
          - fan
        logging:
          options:
            max-size: 10m
            max-file: 1
  '';
in
{
  home.activation.setupCliProxy = lib.hm.dag.entryAfter [ "writeBoundary" "setupDocker" ] ''
    CPA_DIR=/opt/cli-proxy
    AGE_BIN="${pkgs.age}/bin/age"
    AGE_KEY="$HOME/.secrets/age-keys.txt"
    DOCKER="${pkgs.docker}/bin/docker"

    # 1) 目录 + 声明文件（幂等覆盖，声明全在 git）
    mkdir -p "$CPA_DIR/auth-dir" "$CPA_DIR/logs" "$CPA_DIR/static"
    cp -f ${composeYaml} "$CPA_DIR/docker-compose.yml"

    # 2) config.yaml 仅在缺失时解密（首装补一份；此后归用户维护，nix 不覆盖）
    if [[ ! -f "$CPA_DIR/config.yaml" ]]; then
      umask 077
      "$AGE_BIN" -d -i "$AGE_KEY" -o "$CPA_DIR/config.yaml" ${../../..}/secrets/hosts/hc-pro-pve-2/cli-proxy-config.yaml.age
      chmod 600 "$CPA_DIR/config.yaml"
      echo "cli-proxy: 已写入初始 config.yaml（缺失时补）"
    else
      echo "cli-proxy: config.yaml 已存在，跳过（用户维护，nix 不覆盖）"
    fi

    # 拉最新镜像（失败仅警告，继续用现有镜像）
    cd "$CPA_DIR" && "$DOCKER" compose pull \
      || echo "警告: cli-proxy-api 拉取最新镜像失败（registry 不可达？），继续用现有镜像"

    # 3) 幂等拉起（已跑则 no-op；配置变更时 compose 自动重建）
    cd "$CPA_DIR" && "$DOCKER" compose up -d \
      || echo "警告: cli-proxy-api 容器启动失败（docker daemon 未运行？fan 网络不存在？）"

    # 清 dangling 旧镜像（pull+up 后旧镜像失 tag；不用 -a，免误删他服务旧版本与本地构建镜像）
    "$DOCKER" image prune -f \
      || echo "警告: 旧镜像清理失败（不影响服务）"
  '';
}
