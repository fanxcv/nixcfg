# FICC 中间件栈（podman-compose，声明由 nix 渲染派发）
# compose 源：compose-mw.yml（源自迁移档案，口令占位符化；dashboard 端口改 18080 避开 ficc-auth）
# 口令由 /data/.env 注入：age 解密 secrets/hosts/ficc-test-vm/mw-env.age（失败即部署失败，无兜底）
# 三份只读配置（my.cnf / elasticsearch.yml / broker.conf）是机器本地运维资料、不入 git，
#   缺失则容器起不来 -> 前置检查直接报错中止，不带着半套中间件往下走
# 更新流：改 compose-mw.yml → 部署 → activation 覆盖 compose/.env → up -d 重建

{
  lib,
  pkgs,
  ...
}:
{
  home.activation.setupFiccMiddleware = lib.hm.dag.entryAfter [ "writeBoundary" "setupPodman" ] ''
    FICC_MW_DIR=/data
    AGE_BIN="${pkgs.age}/bin/age"
    AGE_KEY="$HOME/.secrets/age-keys.txt"
    PODMAN_COMPOSE="${pkgs.podman-compose}/bin/podman-compose"

    # 1) 目录（挂载点须先存在，否则 podman 会建成 root 属主的空卷）
    mkdir -p /data/{mysql,redis,redis-stack,minio} \
             /data/zookeeper{1,2,3}/{data,datalog,logs} \
             /data/rocketmq/namesrv/logs /data/rocketmq/broker/{conf,store,logs} \
             /data/nacos/{logs,data} /data/es/{data,plugins} \
             /data/config/ficc/{mysql,es}

    # 2) 声明文件（幂等覆盖，声明全在 git）
    cp -f ${./compose-mw.yml} "$FICC_MW_DIR/compose-mw.yml"

    # 3) 口令 env → .env（每次覆盖，源在 secrets；失败即部署失败，无兜底）
    umask 077
    "$AGE_BIN" -d -i "$AGE_KEY" -o "$FICC_MW_DIR/.env" ${../../../secrets/hosts/ficc-test-vm/mw-env.age}
    chmod 600 "$FICC_MW_DIR/.env"

    # 4) 前置检查：只读配置文件不在 git，缺一份就中止（暴露问题，不带病启动）
    for cfg in /data/config/ficc/mysql/my.cnf /data/config/ficc/es/elasticsearch.yml /data/rocketmq/broker/conf/broker.conf; do
      if [ ! -f "$cfg" ]; then
        echo "错误: 缺少只读配置 $cfg，中间件启动中止（请先补齐该文件）"
        exit 1
      fi
    done

    # 5) 幂等拉起（已跑则 no-op；配置变更时 compose 自动重建）
    cd "$FICC_MW_DIR" && "$PODMAN_COMPOSE" -f "$FICC_MW_DIR/compose-mw.yml" --env-file "$FICC_MW_DIR/.env" up -d
  '';
}
