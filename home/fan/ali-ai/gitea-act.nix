# Gitea act_runner（docker compose，声明由 nix 渲染派发）
# 参考：10.2.241.65:/opt/gitea/act（instance hc-git.qksxin.com；labels/cache 按本机调整）
# 容器运行时仍 docker（B 路线）；compose+config 由 nix 生成，token 走 secrets（age 加密）
# 数据目录 /opt/gitea-act/{cache,data} 是状态，不归 nix（与 tailscale state 同哲学）
# 更新流：改本文件 → 部署 → activation 覆盖 compose/config → docker compose up -d 重建

{
  lib,
  pkgs,
  ...
}:
let
  composeYaml = pkgs.writeText "gitea-act-compose.yml" ''
    services:
      runner:
        image: docker.1ms.run/gitea/act_runner
        container_name: gitea-act
        restart: always
        environment:
          CONFIG_FILE: /config.yaml
          GITEA_INSTANCE_URL: https://hc-git.qksxin.com
          GITEA_RUNNER_NAME: ali-ai
          GITEA_RUNNER_REGISTRATION_TOKEN: ''${GITEA_RUNNER_REGISTRATION_TOKEN}
        ports:
          - 18088:18088
        volumes:
          - ./config.yaml:/config.yaml
          - ./cache:/root/.cache
          - ./data:/data
          - /var/run/docker.sock:/var/run/docker.sock
  '';
  configYaml = pkgs.writeText "gitea-act-config.yaml" ''
    log:
      level: info
    runner:
      file: .runner
      capacity: 3
      envs: {}
      timeout: 3h
      insecure: false
      fetch_timeout: 5s
      fetch_interval: 2s
      labels: ['ali-ai']
    cache:
      enabled: true
      dir: ""
      host: "10.1.0.18"
      port: 18088
      external_server: ""
    container:
      network: ""
      privileged: false
      options:
      workdir_parent:
      valid_volumes: ["**"]
      docker_host: ""
  '';
in
{
  home.activation.setupGiteaAct = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ACT_DIR=/opt/gitea-act
    AGE_BIN="${pkgs.age}/bin/age"
    AGE_KEY="$HOME/.secrets/age-keys.txt"
    DOCKER="${pkgs.docker}/bin/docker"

    # 1) 目录 + 声明文件（幂等覆盖，声明全在 git）
    mkdir -p "$ACT_DIR/cache" "$ACT_DIR/data"
    cp -f ${composeYaml} "$ACT_DIR/docker-compose.yml"
    cp -f ${configYaml} "$ACT_DIR/config.yaml"

    # 2) token 解密 → .env（compose 变量替换源；失败即部署失败）
    umask 077
    "$AGE_BIN" -d -i "$AGE_KEY" -o "$ACT_DIR/.env" ${../../..}/secrets/hosts/ali-ai/gitea-act-token.age
    chmod 600 "$ACT_DIR/.env"

    # 3) 幂等拉起（已跑则 no-op；配置变更时 compose 自动重建）
    cd "$ACT_DIR" && "$DOCKER" compose up -d \
      || echo "警告: gitea-act 容器启动失败（docker daemon 未运行？）"
  '';
}
