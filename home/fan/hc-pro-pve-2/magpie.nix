# magpie（docker compose，声明由 nix 渲染派发）
# 镜像 ghcr.io/yetone/magpie（实测该机可直连，见 lane 报告）；Web UI 3430 + gateway 3425，宿主端口直连
# 上游 CMD 为 serve（无 UI），故必须覆盖 command 起 web
# 唯一状态卷 ./config（容器以 uid 65532 跑，须可写）；密钥 MAGPIE_WEB_KEY 由 /opt/magpie/.env 注入
# 更新流：改本文件 → 部署 → activation 补 compose/.env → pull 最新镜像 → up -d 重建 → 清 dangling 旧镜像

{
  lib,
  pkgs,
  ...
}:
let
  composeYaml = pkgs.writeText "magpie-compose.yml" ''
    services:
      magpie:
        image: ghcr.io/yetone/magpie:latest
        container_name: magpie
        restart: always
        command: [web, "--addr", "0.0.0.0:3430", "--no-open"]
        ports:
          - 3425:3425
          - 3430:3430
        volumes:
          - ./config:/config
        environment:
          MAGPIE_WEB_KEY: ''${MAGPIE_WEB_KEY}
          DO_NOT_TRACK: "1"
        logging:
          options:
            max-size: 10m
            max-file: 1
  '';
in
{
  home.activation.setupMagpie = lib.hm.dag.entryAfter [ "writeBoundary" "setupDocker" ] ''
    MAGPIE_DIR=/opt/magpie
    AGE_BIN="${pkgs.age}/bin/age"
    AGE_KEY="$HOME/.secrets/age-keys.txt"
    DOCKER="${pkgs.docker}/bin/docker"

    # 1) 目录 + 属主（容器 uid 65532，config 须可写）
    mkdir -p "$MAGPIE_DIR/config"
    chown -R 65532:65532 "$MAGPIE_DIR/config"

    # 2) 声明文件（幂等覆盖，声明全在 git）
    cp -f ${composeYaml} "$MAGPIE_DIR/docker-compose.yml"

    # 3) 密钥 → .env（每次覆盖，源在 secrets；失败即部署失败，无兜底）
    umask 077
    "$AGE_BIN" -d -i "$AGE_KEY" -o "$MAGPIE_DIR/.env" ${../../..}/secrets/hosts/hc-pro-pve-2/magpie-web-key.age
    chmod 600 "$MAGPIE_DIR/.env"

    # 4) 拉最新镜像（失败仅警告，继续用现有镜像）
    cd "$MAGPIE_DIR" && "$DOCKER" compose pull \
      || echo "警告: magpie 拉取最新镜像失败（registry 不可达？），继续用现有镜像"

    # 5) 幂等拉起（已跑则 no-op；配置变更时 compose 自动重建）
    cd "$MAGPIE_DIR" && "$DOCKER" compose up -d \
      || echo "警告: magpie 容器启动失败（docker daemon 未运行？3430/3425 被占？）"

    # 6) 清 dangling 旧镜像（pull+up 后旧镜像失 tag；不用 -a，免误删他服务旧版本与本地构建镜像）
    "$DOCKER" image prune -f \
      || echo "警告: 旧镜像清理失败（不影响服务）"
  '';
}
