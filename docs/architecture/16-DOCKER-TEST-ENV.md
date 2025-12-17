# Docker 测试环境部署指南

> 基于 Docker Compose 的本地/测试环境一键部署方案

## 容器清单总览

### 版本选型原则

- 选择 LTS 或稳定版本
- 避免 latest 标签，锁定具体版本
- 优先选择官方镜像或知名维护者镜像

### 容器分类

| 分类 | 容器 | 版本 | 端口 | 用途 |
|------|------|------|------|------|
| **网关代理** | nginx-ui | 2.0.0-beta.37 | 80, 443, 8080 | Nginx可视化管理 |
| **注册配置** | nacos | 2.4.3 | 8848, 9848, 9849 | 服务注册与配置中心 |
| **数据库** | mysql | 8.0.40 | 3306 | 关系型数据库 |
| **数据库** | postgres | 16.6 | 5432 | 关系型数据库(可选) |
| **缓存** | redis | 7.4.1 | 6379 | 缓存与会话存储 |
| **消息队列** | rocketmq | 5.3.1 | 9876, 10911, 10912 | 消息中间件 |
| **消息队列** | rabbitmq | 4.0.4 | 5672, 15672 | 消息中间件(可选) |
| **搜索引擎** | elasticsearch | 8.17.0 | 9200, 9300 | 全文搜索与日志存储 |
| **搜索可视化** | kibana | 8.17.0 | 5601 | ES可视化管理 |
| **监控** | prometheus | 2.55.1 | 9090 | 指标采集与存储 |
| **监控** | grafana | 11.4.0 | 3000 | 监控可视化 |
| **日志** | loki | 3.3.2 | 3100 | 日志聚合 |
| **链路追踪** | tempo | 2.6.1 | 3200, 4317, 4318 | 分布式追踪 |
| **链路追踪** | jaeger | 1.64.0 | 16686, 4317, 4318 | 分布式追踪(可选) |
| **任务调度** | xxl-job-admin | 2.4.2 | 8800 | 分布式任务调度 |
| **文件存储** | minio | RELEASE.2024-12-13 | 9000, 9001 | 对象存储 |
| **数据库管理** | adminer | 4.8.1 | 8081 | 轻量数据库管理 |
| **Redis管理** | redis-commander | 0.8.1 | 8082 | Redis可视化管理 |

## 目录结构

```
docker-test-env/
├── docker-compose.yml          # 主编排文件
├── docker-compose.override.yml # 本地覆盖配置
├── .env                        # 环境变量
├── config/
│   ├── nginx/
│   │   └── conf.d/
│   ├── nacos/
│   │   └── application.properties
│   ├── mysql/
│   │   ├── my.cnf
│   │   └── init/
│   │       └── init.sql
│   ├── redis/
│   │   └── redis.conf
│   ├── rocketmq/
│   │   ├── broker.conf
│   │   └── namesrv.conf
│   ├── elasticsearch/
│   │   └── elasticsearch.yml
│   ├── prometheus/
│   │   └── prometheus.yml
│   ├── grafana/
│   │   ├── provisioning/
│   │   │   ├── dashboards/
│   │   │   └── datasources/
│   │   └── grafana.ini
│   ├── loki/
│   │   └── loki-config.yml
│   └── tempo/
│       └── tempo-config.yml
├── data/                       # 数据持久化目录
│   ├── mysql/
│   ├── redis/
│   ├── nacos/
│   ├── elasticsearch/
│   ├── prometheus/
│   ├── grafana/
│   ├── minio/
│   └── xxl-job/
└── logs/                       # 日志目录
```

## 环境变量文件 (.env)

```bash
# ==================== 基础配置 ====================
COMPOSE_PROJECT_NAME=platform-test
TIMEZONE=Asia/Shanghai

# ==================== MySQL ====================
MYSQL_VERSION=8.0.40
MYSQL_ROOT_PASSWORD=root123456
MYSQL_DATABASE=platform
MYSQL_USER=platform
MYSQL_PASSWORD=platform123

# ==================== PostgreSQL ====================
POSTGRES_VERSION=16.6-alpine
POSTGRES_USER=platform
POSTGRES_PASSWORD=platform123
POSTGRES_DB=platform

# ==================== Redis ====================
REDIS_VERSION=7.4.1-alpine
REDIS_PASSWORD=redis123456

# ==================== Nacos ====================
NACOS_VERSION=v2.4.3
NACOS_AUTH_ENABLE=true
NACOS_AUTH_TOKEN=SecretKey012345678901234567890123456789012345678901234567890123456789
NACOS_AUTH_IDENTITY_KEY=serverIdentity
NACOS_AUTH_IDENTITY_VALUE=security

# ==================== RocketMQ ====================
ROCKETMQ_VERSION=5.3.1
ROCKETMQ_DASHBOARD_VERSION=1.0.0

# ==================== Elasticsearch ====================
ES_VERSION=8.17.0
ES_JAVA_OPTS=-Xms512m -Xmx512m
ELASTIC_PASSWORD=elastic123

# ==================== 监控组件 ====================
PROMETHEUS_VERSION=v2.55.1
GRAFANA_VERSION=11.4.0
LOKI_VERSION=3.3.2
TEMPO_VERSION=2.6.1
JAEGER_VERSION=1.64.0

# ==================== 其他组件 ====================
MINIO_VERSION=RELEASE.2024-12-13T22-19-12Z
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

XXL_JOB_VERSION=2.4.2
XXL_JOB_ADMIN_PASSWORD=123456

NGINX_UI_VERSION=2.0.0-beta.37

ADMINER_VERSION=4.8.1
REDIS_COMMANDER_VERSION=0.8.1
```

## Docker Compose 配置

### docker-compose.yml

```yaml
version: '3.8'

services:
  # ==================== 网关代理 ====================
  nginx-ui:
    image: uozi/nginx-ui:${NGINX_UI_VERSION:-2.0.0-beta.37}
    container_name: nginx-ui
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:80"  # nginx-ui管理界面
    volumes:
      - ./config/nginx:/etc/nginx
      - ./data/nginx-ui:/etc/nginx-ui
      - ./logs/nginx:/var/log/nginx
    environment:
      - TZ=${TIMEZONE:-Asia/Shanghai}
    networks:
      - platform-network

  # ==================== 注册配置中心 ====================
  nacos:
    image: nacos/nacos-server:${NACOS_VERSION:-v2.4.3}
    container_name: nacos
    restart: unless-stopped
    ports:
      - "8848:8848"
      - "9848:9848"
      - "9849:9849"
    environment:
      - MODE=standalone
      - PREFER_HOST_MODE=hostname
      - SPRING_DATASOURCE_PLATFORM=mysql
      - MYSQL_SERVICE_HOST=mysql
      - MYSQL_SERVICE_PORT=3306
      - MYSQL_SERVICE_DB_NAME=nacos
      - MYSQL_SERVICE_USER=${MYSQL_USER:-platform}
      - MYSQL_SERVICE_PASSWORD=${MYSQL_PASSWORD:-platform123}
      - MYSQL_SERVICE_DB_PARAM=characterEncoding=utf8&connectTimeout=10000&socketTimeout=30000&autoReconnect=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai
      - NACOS_AUTH_ENABLE=${NACOS_AUTH_ENABLE:-true}
      - NACOS_AUTH_TOKEN=${NACOS_AUTH_TOKEN}
      - NACOS_AUTH_IDENTITY_KEY=${NACOS_AUTH_IDENTITY_KEY:-serverIdentity}
      - NACOS_AUTH_IDENTITY_VALUE=${NACOS_AUTH_IDENTITY_VALUE:-security}
      - JVM_XMS=256m
      - JVM_XMX=512m
      - JVM_XMN=128m
      - TZ=${TIMEZONE:-Asia/Shanghai}
    volumes:
      - ./data/nacos/logs:/home/nacos/logs
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - platform-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8848/nacos/v1/console/health/readiness"]
      interval: 10s
      timeout: 5s
      retries: 10

  # ==================== 数据库 ====================
  mysql:
    image: mysql:${MYSQL_VERSION:-8.0.40}
    container_name: mysql
    restart: unless-stopped
    ports:
      - "3306:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-root123456}
      - MYSQL_DATABASE=${MYSQL_DATABASE:-platform}
      - MYSQL_USER=${MYSQL_USER:-platform}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD:-platform123}
      - TZ=${TIMEZONE:-Asia/Shanghai}
    command:
      - --default-authentication-plugin=caching_sha2_password
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --max_connections=1000
      - --innodb_buffer_pool_size=256M
      - --slow_query_log=1
      - --slow_query_log_file=/var/log/mysql/slow.log
      - --long_query_time=2
    volumes:
      - ./data/mysql:/var/lib/mysql
      - ./config/mysql/init:/docker-entrypoint-initdb.d
      - ./logs/mysql:/var/log/mysql
    networks:
      - platform-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD:-root123456}"]
      interval: 10s
      timeout: 5s
      retries: 10

  postgres:
    image: postgres:${POSTGRES_VERSION:-16.6-alpine}
    container_name: postgres
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=${POSTGRES_USER:-platform}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-platform123}
      - POSTGRES_DB=${POSTGRES_DB:-platform}
      - TZ=${TIMEZONE:-Asia/Shanghai}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    networks:
      - platform-network
    profiles:
      - postgres

  # ==================== 缓存 ====================
  redis:
    image: redis:${REDIS_VERSION:-7.4.1-alpine}
    container_name: redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    command: redis-server --requirepass ${REDIS_PASSWORD:-redis123456} --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - ./data/redis:/data
    networks:
      - platform-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-redis123456}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ==================== 消息队列 ====================
  rocketmq-namesrv:
    image: apache/rocketmq:${ROCKETMQ_VERSION:-5.3.1}
    container_name: rocketmq-namesrv
    restart: unless-stopped
    ports:
      - "9876:9876"
    environment:
      - JAVA_OPT_EXT=-Xms256m -Xmx256m -Xmn128m
    command: sh mqnamesrv
    volumes:
      - ./data/rocketmq/namesrv/logs:/home/rocketmq/logs
    networks:
      - platform-network
    healthcheck:
      test: ["CMD", "sh", "-c", "echo 'health check' | nc localhost 9876 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5

  rocketmq-broker:
    image: apache/rocketmq:${ROCKETMQ_VERSION:-5.3.1}
    container_name: rocketmq-broker
    restart: unless-stopped
    ports:
      - "10911:10911"
      - "10912:10912"
    environment:
      - JAVA_OPT_EXT=-Xms512m -Xmx512m -Xmn256m
      - NAMESRV_ADDR=rocketmq-namesrv:9876
    command: sh mqbroker -c /home/rocketmq/conf/broker.conf
    volumes:
      - ./config/rocketmq/broker.conf:/home/rocketmq/conf/broker.conf
      - ./data/rocketmq/broker/logs:/home/rocketmq/logs
      - ./data/rocketmq/broker/store:/home/rocketmq/store
    depends_on:
      rocketmq-namesrv:
        condition: service_healthy
    networks:
      - platform-network

  rocketmq-dashboard:
    image: apacherocketmq/rocketmq-dashboard:${ROCKETMQ_DASHBOARD_VERSION:-1.0.0}
    container_name: rocketmq-dashboard
    restart: unless-stopped
    ports:
      - "8180:8080"
    environment:
      - JAVA_OPTS=-Xms128m -Xmx256m -Drocketmq.namesrv.addr=rocketmq-namesrv:9876
    depends_on:
      - rocketmq-namesrv
    networks:
      - platform-network

  rabbitmq:
    image: rabbitmq:${RABBITMQ_VERSION:-4.0.4-management-alpine}
    container_name: rabbitmq
    restart: unless-stopped
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      - RABBITMQ_DEFAULT_USER=admin
      - RABBITMQ_DEFAULT_PASS=admin123
    volumes:
      - ./data/rabbitmq:/var/lib/rabbitmq
    networks:
      - platform-network
    profiles:
      - rabbitmq

  # ==================== 搜索引擎 ====================
  elasticsearch:
    image: elasticsearch:${ES_VERSION:-8.17.0}
    container_name: elasticsearch
    restart: unless-stopped
    ports:
      - "9200:9200"
      - "9300:9300"
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - xpack.security.enrollment.enabled=false
      - ES_JAVA_OPTS=${ES_JAVA_OPTS:--Xms512m -Xmx512m}
      - TZ=${TIMEZONE:-Asia/Shanghai}
    volumes:
      - ./data/elasticsearch:/usr/share/elasticsearch/data
      - ./config/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml
    networks:
      - platform-network
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:9200/_cluster/health | grep -q 'green\\|yellow'"]
      interval: 30s
      timeout: 10s
      retries: 5
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536

  kibana:
    image: kibana:${ES_VERSION:-8.17.0}
    container_name: kibana
    restart: unless-stopped
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - I18N_LOCALE=zh-CN
      - TZ=${TIMEZONE:-Asia/Shanghai}
    depends_on:
      elasticsearch:
        condition: service_healthy
    networks:
      - platform-network

  # ==================== 监控组件 ====================
  prometheus:
    image: prom/prometheus:${PROMETHEUS_VERSION:-v2.55.1}
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    volumes:
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./data/prometheus:/prometheus
    networks:
      - platform-network

  grafana:
    image: grafana/grafana:${GRAFANA_VERSION:-11.4.0}
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3000
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-piechart-panel
      - TZ=${TIMEZONE:-Asia/Shanghai}
    volumes:
      - ./data/grafana:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning
    depends_on:
      - prometheus
      - loki
    networks:
      - platform-network

  # ==================== 日志组件 ====================
  loki:
    image: grafana/loki:${LOKI_VERSION:-3.3.2}
    container_name: loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/loki-config.yml
    volumes:
      - ./config/loki/loki-config.yml:/etc/loki/loki-config.yml
      - ./data/loki:/loki
    networks:
      - platform-network

  promtail:
    image: grafana/promtail:${LOKI_VERSION:-3.3.2}
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ./config/promtail/promtail-config.yml:/etc/promtail/promtail-config.yml
      - ./logs:/var/log/apps
      - /var/run/docker.sock:/var/run/docker.sock
    command: -config.file=/etc/promtail/promtail-config.yml
    depends_on:
      - loki
    networks:
      - platform-network

  # ==================== 链路追踪 ====================
  tempo:
    image: grafana/tempo:${TEMPO_VERSION:-2.6.1}
    container_name: tempo
    restart: unless-stopped
    ports:
      - "3200:3200"   # tempo http
      - "4317:4317"   # otlp grpc
      - "4318:4318"   # otlp http
      - "9411:9411"   # zipkin
    command: ["-config.file=/etc/tempo/tempo-config.yml"]
    volumes:
      - ./config/tempo/tempo-config.yml:/etc/tempo/tempo-config.yml
      - ./data/tempo:/tmp/tempo
    networks:
      - platform-network

  jaeger:
    image: jaegertracing/all-in-one:${JAEGER_VERSION:-1.64.0}
    container_name: jaeger
    restart: unless-stopped
    ports:
      - "16686:16686"  # UI
      - "14268:14268"  # jaeger http
      - "6831:6831/udp" # jaeger thrift
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    networks:
      - platform-network
    profiles:
      - jaeger

  # ==================== 任务调度 ====================
  xxl-job-admin:
    image: xuxueli/xxl-job-admin:${XXL_JOB_VERSION:-2.4.2}
    container_name: xxl-job-admin
    restart: unless-stopped
    ports:
      - "8800:8080"
    environment:
      - PARAMS=--spring.datasource.url=jdbc:mysql://mysql:3306/xxl_job?useUnicode=true&characterEncoding=UTF-8&autoReconnect=true&serverTimezone=Asia/Shanghai --spring.datasource.username=${MYSQL_USER:-platform} --spring.datasource.password=${MYSQL_PASSWORD:-platform123}
    volumes:
      - ./data/xxl-job:/data/applogs
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - platform-network

  # ==================== 对象存储 ====================
  minio:
    image: minio/minio:${MINIO_VERSION:-RELEASE.2024-12-13T22-19-12Z}
    container_name: minio
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      - MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}
      - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin123}
      - TZ=${TIMEZONE:-Asia/Shanghai}
    command: server /data --console-address ":9001"
    volumes:
      - ./data/minio:/data
    networks:
      - platform-network
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ==================== 管理工具 ====================
  adminer:
    image: adminer:${ADMINER_VERSION:-4.8.1}
    container_name: adminer
    restart: unless-stopped
    ports:
      - "8081:8080"
    environment:
      - ADMINER_DEFAULT_SERVER=mysql
    networks:
      - platform-network

  redis-commander:
    image: rediscommander/redis-commander:${REDIS_COMMANDER_VERSION:-latest}
    container_name: redis-commander
    restart: unless-stopped
    ports:
      - "8082:8081"
    environment:
      - REDIS_HOSTS=local:redis:6379:0:${REDIS_PASSWORD:-redis123456}
    depends_on:
      - redis
    networks:
      - platform-network

networks:
  platform-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

## 配置文件

### MySQL 初始化脚本 (config/mysql/init/init.sql)

```sql
-- 创建 Nacos 数据库
CREATE DATABASE IF NOT EXISTS `nacos` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建 XXL-JOB 数据库
CREATE DATABASE IF NOT EXISTS `xxl_job` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建业务数据库
CREATE DATABASE IF NOT EXISTS `platform` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 授权
GRANT ALL PRIVILEGES ON nacos.* TO 'platform'@'%';
GRANT ALL PRIVILEGES ON xxl_job.* TO 'platform'@'%';
GRANT ALL PRIVILEGES ON platform.* TO 'platform'@'%';
FLUSH PRIVILEGES;

-- 使用 Nacos 数据库
USE nacos;

-- Nacos 表结构 (https://github.com/alibaba/nacos/blob/master/distribution/conf/mysql-schema.sql)
-- 这里简化，实际使用时需要导入完整的 schema

CREATE TABLE IF NOT EXISTS `config_info` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT,
    `data_id` varchar(255) NOT NULL,
    `group_id` varchar(255) DEFAULT NULL,
    `content` longtext NOT NULL,
    `md5` varchar(32) DEFAULT NULL,
    `gmt_create` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `gmt_modified` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `src_user` text,
    `src_ip` varchar(50) DEFAULT NULL,
    `app_name` varchar(128) DEFAULT NULL,
    `tenant_id` varchar(128) DEFAULT '',
    `c_desc` varchar(256) DEFAULT NULL,
    `c_use` varchar(64) DEFAULT NULL,
    `effect` varchar(64) DEFAULT NULL,
    `type` varchar(64) DEFAULT NULL,
    `c_schema` text,
    `encrypted_data_key` varchar(1024) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_configinfo_datagrouptenant` (`data_id`,`group_id`,`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
```

### RocketMQ Broker 配置 (config/rocketmq/broker.conf)

```properties
# Broker 集群名称
brokerClusterName = DefaultCluster
# Broker 名称
brokerName = broker-a
# Broker ID, 0表示Master, 非0表示Slave
brokerId = 0
# 删除文件时间点，默认凌晨4点
deleteWhen = 04
# 文件保留时间，默认48小时
fileReservedTime = 48
# Broker角色
brokerRole = ASYNC_MASTER
# 刷盘方式
flushDiskType = ASYNC_FLUSH
# NameServer地址
namesrvAddr = rocketmq-namesrv:9876
# 自动创建Topic
autoCreateTopicEnable = true
# 自动创建订阅组
autoCreateSubscriptionGroup = true
# Broker IP (Docker环境需要设置为宿主机IP或容器网络IP)
brokerIP1 = rocketmq-broker
# 监听端口
listenPort = 10911
# 存储路径
storePathRootDir = /home/rocketmq/store
storePathCommitLog = /home/rocketmq/store/commitlog
# 内存配置
slaveReadEnable = true
```

### Elasticsearch 配置 (config/elasticsearch/elasticsearch.yml)

```yaml
cluster.name: platform-es
node.name: es-node-1
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node

# 安全设置 (测试环境关闭)
xpack.security.enabled: false
xpack.security.enrollment.enabled: false

# 内存设置
bootstrap.memory_lock: true

# 跨域设置
http.cors.enabled: true
http.cors.allow-origin: "*"

# 索引设置
action.auto_create_index: true
```

### Prometheus 配置 (config/prometheus/prometheus.yml)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files: []

scrape_configs:
  # Prometheus 自身
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Spring Boot 应用
  - job_name: 'spring-boot'
    metrics_path: '/actuator/prometheus'
    scrape_interval: 10s
    static_configs:
      - targets: ['host.docker.internal:8080']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '(.+):\d+'
        replacement: '${1}'

  # Node Exporter (如果有)
  - job_name: 'node'
    static_configs:
      - targets: ['host.docker.internal:9100']

  # MySQL Exporter
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-exporter:9104']

  # Redis Exporter
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  # Nacos
  - job_name: 'nacos'
    metrics_path: '/nacos/actuator/prometheus'
    static_configs:
      - targets: ['nacos:8848']
```

### Loki 配置 (config/loki/loki-config.yml)

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: info

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  filesystem:
    directory: /loki/chunks

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32
  max_streams_per_user: 10000

compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150

analytics:
  reporting_enabled: false
```

### Promtail 配置 (config/promtail/promtail-config.yml)

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Docker 容器日志
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*log

    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag:
          source: attrs
      - regex:
          expression: (?P<container_name>(?:[a-zA-Z0-9][a-zA-Z0-9_.-]+))
          source: tag
      - labels:
          stream:
          container_name:
      - output:
          source: output

  # 应用日志文件
  - job_name: app-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: applogs
          __path__: /var/log/apps/**/*.log
    pipeline_stages:
      - multiline:
          firstline: '^\d{4}-\d{2}-\d{2}'
          max_wait_time: 3s
      - regex:
          expression: '^(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\s+(?P<level>\w+)\s+\[(?P<thread>[^\]]+)\]\s+(?P<logger>[^\s]+)\s+-\s+(?P<message>.*)$'
      - labels:
          level:
          thread:
          logger:
      - timestamp:
          source: timestamp
          format: '2006-01-02 15:04:05.000'
```

### Tempo 配置 (config/tempo/tempo-config.yml)

```yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
    zipkin:
      endpoint: 0.0.0.0:9411

ingester:
  trace_idle_period: 10s
  max_block_bytes: 1_000_000
  max_block_duration: 5m

compactor:
  compaction:
    compaction_window: 1h
    max_block_bytes: 100_000_000
    block_retention: 1h
    compacted_block_retention: 10m

storage:
  trace:
    backend: local
    wal:
      path: /tmp/tempo/wal
    local:
      path: /tmp/tempo/blocks

metrics_generator:
  registry:
    external_labels:
      source: tempo
  storage:
    path: /tmp/tempo/generator/wal
    remote_write:
      - url: http://prometheus:9090/api/v1/write
        send_exemplars: true

overrides:
  defaults:
    metrics_generator:
      processors: [service-graphs, span-metrics]
```

### Grafana 数据源配置 (config/grafana/provisioning/datasources/datasources.yml)

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
    jsonData:
      derivedFields:
        - datasourceUid: tempo
          matcherRegex: "traceId=(\\w+)"
          name: TraceID
          url: '$${__value.raw}'

  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    uid: tempo
    editable: true
    jsonData:
      httpMethod: GET
      tracesToLogs:
        datasourceUid: loki
        tags: ['job', 'instance', 'pod', 'namespace']
        mappedTags: [{ key: 'service.name', value: 'service' }]
        mapTagNamesEnabled: false
        spanStartTimeShift: '1h'
        spanEndTimeShift: '-1h'
        filterByTraceID: false
        filterBySpanID: false
      serviceMap:
        datasourceUid: prometheus
      nodeGraph:
        enabled: true
      search:
        hide: false
      lokiSearch:
        datasourceUid: loki

  - name: Elasticsearch
    type: elasticsearch
    access: proxy
    url: http://elasticsearch:9200
    database: "*"
    editable: true
    jsonData:
      esVersion: "8.0.0"
      timeField: "@timestamp"
      logMessageField: message
      logLevelField: level
```

## 启动脚本

### 启动脚本 (start.sh / start.bat)

**Linux/Mac (start.sh)**:
```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 创建必要目录
mkdir -p data/{mysql,redis,nacos,elasticsearch,prometheus,grafana,minio,xxl-job,loki,tempo,rocketmq/{namesrv,broker}/{logs,store},nginx-ui,postgres,rabbitmq}
mkdir -p logs/{nginx,mysql}
mkdir -p config/{nginx/conf.d,nacos,mysql/init,redis,rocketmq,elasticsearch,prometheus,grafana/provisioning/{dashboards,datasources},loki,tempo,promtail}

# 设置权限
chmod -R 777 data logs

echo "=============================="
echo "Starting Platform Test Environment"
echo "=============================="

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed!"
    exit 1
fi

# 启动基础服务
echo "[1/4] Starting infrastructure services..."
docker compose up -d mysql redis

echo "Waiting for MySQL to be ready..."
sleep 30

# 启动中间件
echo "[2/4] Starting middleware services..."
docker compose up -d nacos rocketmq-namesrv rocketmq-broker elasticsearch

echo "Waiting for middleware to be ready..."
sleep 30

# 启动可观测性组件
echo "[3/4] Starting observability services..."
docker compose up -d prometheus loki tempo grafana

# 启动其他服务
echo "[4/4] Starting other services..."
docker compose up -d nginx-ui minio xxl-job-admin kibana rocketmq-dashboard adminer redis-commander promtail

echo "=============================="
echo "All services started!"
echo "=============================="
echo ""
echo "Service URLs:"
echo "  - Nginx UI:           http://localhost:8080"
echo "  - Nacos:              http://localhost:8848/nacos"
echo "  - Grafana:            http://localhost:3000 (admin/admin123)"
echo "  - Prometheus:         http://localhost:9090"
echo "  - Kibana:             http://localhost:5601"
echo "  - RocketMQ Dashboard: http://localhost:8180"
echo "  - XXL-JOB Admin:      http://localhost:8800/xxl-job-admin (admin/123456)"
echo "  - MinIO:              http://localhost:9001 (minioadmin/minioadmin123)"
echo "  - Adminer:            http://localhost:8081"
echo "  - Redis Commander:    http://localhost:8082"
echo ""
```

**Windows (start.bat)**:
```batch
@echo off
setlocal enabledelayedexpansion

echo ==============================
echo Starting Platform Test Environment
echo ==============================

:: 创建目录
mkdir data\mysql 2>nul
mkdir data\redis 2>nul
mkdir data\nacos 2>nul
mkdir data\elasticsearch 2>nul
mkdir data\prometheus 2>nul
mkdir data\grafana 2>nul
mkdir data\minio 2>nul
mkdir data\xxl-job 2>nul
mkdir data\loki 2>nul
mkdir data\tempo 2>nul
mkdir data\rocketmq\namesrv\logs 2>nul
mkdir data\rocketmq\broker\logs 2>nul
mkdir data\rocketmq\broker\store 2>nul
mkdir data\nginx-ui 2>nul
mkdir logs\nginx 2>nul
mkdir logs\mysql 2>nul
mkdir config\nginx\conf.d 2>nul
mkdir config\mysql\init 2>nul
mkdir config\grafana\provisioning\dashboards 2>nul
mkdir config\grafana\provisioning\datasources 2>nul

:: 启动基础服务
echo [1/4] Starting infrastructure services...
docker compose up -d mysql redis
timeout /t 30 /nobreak > nul

:: 启动中间件
echo [2/4] Starting middleware services...
docker compose up -d nacos rocketmq-namesrv rocketmq-broker elasticsearch
timeout /t 30 /nobreak > nul

:: 启动可观测性组件
echo [3/4] Starting observability services...
docker compose up -d prometheus loki tempo grafana

:: 启动其他服务
echo [4/4] Starting other services...
docker compose up -d nginx-ui minio xxl-job-admin kibana rocketmq-dashboard adminer redis-commander promtail

echo ==============================
echo All services started!
echo ==============================
echo.
echo Service URLs:
echo   - Nginx UI:           http://localhost:8080
echo   - Nacos:              http://localhost:8848/nacos
echo   - Grafana:            http://localhost:3000 (admin/admin123)
echo   - Prometheus:         http://localhost:9090
echo   - Kibana:             http://localhost:5601
echo   - RocketMQ Dashboard: http://localhost:8180
echo   - XXL-JOB Admin:      http://localhost:8800/xxl-job-admin
echo   - MinIO:              http://localhost:9001
echo   - Adminer:            http://localhost:8081
echo   - Redis Commander:    http://localhost:8082
echo.

pause
```

### 停止脚本 (stop.sh / stop.bat)

**Linux/Mac (stop.sh)**:
```bash
#!/bin/bash
docker compose down
echo "All services stopped."
```

**Windows (stop.bat)**:
```batch
@echo off
docker compose down
echo All services stopped.
pause
```

### 清理脚本 (clean.sh / clean.bat)

**Linux/Mac (clean.sh)**:
```bash
#!/bin/bash
echo "WARNING: This will delete all data!"
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker compose down -v
    rm -rf data/*
    rm -rf logs/*
    echo "All data cleaned."
fi
```

**Windows (clean.bat)**:
```batch
@echo off
echo WARNING: This will delete all data!
set /p confirm="Are you sure? (y/N) "
if /i "%confirm%"=="y" (
    docker compose down -v
    rmdir /s /q data
    rmdir /s /q logs
    echo All data cleaned.
)
pause
```

## 端口映射总览

| 端口 | 服务 | 说明 |
|------|------|------|
| 80 | nginx-ui | HTTP |
| 443 | nginx-ui | HTTPS |
| 3000 | Grafana | 监控可视化 |
| 3100 | Loki | 日志服务 |
| 3200 | Tempo | 链路追踪 |
| 3306 | MySQL | 数据库 |
| 4317 | Tempo | OTLP gRPC |
| 4318 | Tempo | OTLP HTTP |
| 5432 | PostgreSQL | 数据库(可选) |
| 5601 | Kibana | ES可视化 |
| 5672 | RabbitMQ | AMQP(可选) |
| 6379 | Redis | 缓存 |
| 8080 | nginx-ui | 管理界面 |
| 8081 | Adminer | 数据库管理 |
| 8082 | Redis Commander | Redis管理 |
| 8180 | RocketMQ Dashboard | MQ管理 |
| 8800 | XXL-JOB Admin | 任务调度 |
| 8848 | Nacos | 注册配置中心 |
| 9000 | MinIO | S3 API |
| 9001 | MinIO | 控制台 |
| 9090 | Prometheus | 监控 |
| 9200 | Elasticsearch | 搜索 |
| 9411 | Tempo | Zipkin |
| 9848-9849 | Nacos | gRPC |
| 9876 | RocketMQ NameSrv | 名称服务 |
| 10911-10912 | RocketMQ Broker | Broker |
| 15672 | RabbitMQ | 管理界面(可选) |
| 16686 | Jaeger | UI(可选) |

## 资源估算

### 最小配置 (开发环境)

| 组件 | CPU | 内存 |
|------|-----|------|
| MySQL | 0.5c | 512MB |
| Redis | 0.25c | 256MB |
| Nacos | 0.5c | 512MB |
| RocketMQ | 1c | 1GB |
| Elasticsearch | 1c | 1GB |
| Prometheus | 0.5c | 512MB |
| Grafana | 0.25c | 256MB |
| Loki | 0.5c | 512MB |
| Tempo | 0.5c | 512MB |
| **合计** | **~5c** | **~5GB** |

### 推荐配置 (测试环境)

| 组件 | CPU | 内存 |
|------|-----|------|
| MySQL | 1c | 1GB |
| Redis | 0.5c | 512MB |
| Nacos | 1c | 1GB |
| RocketMQ | 2c | 2GB |
| Elasticsearch | 2c | 2GB |
| Prometheus | 1c | 1GB |
| Grafana | 0.5c | 512MB |
| Loki | 1c | 1GB |
| Tempo | 1c | 1GB |
| MinIO | 0.5c | 512MB |
| 其他 | 1c | 1GB |
| **合计** | **~12c** | **~12GB** |

## 常用命令

```bash
# 查看所有容器状态
docker compose ps

# 查看日志
docker compose logs -f [service_name]

# 重启服务
docker compose restart [service_name]

# 进入容器
docker compose exec [service_name] sh

# 启用可选服务 (如 PostgreSQL)
docker compose --profile postgres up -d postgres

# 启用可选服务 (如 Jaeger)
docker compose --profile jaeger up -d jaeger

# 查看资源使用
docker stats

# 导出 MySQL 数据
docker compose exec mysql mysqldump -u root -p platform > backup.sql

# 导入 MySQL 数据
docker compose exec -T mysql mysql -u root -p platform < backup.sql
```

## 版本更新记录

| 日期 | 版本 | 变更内容 |
|------|------|----------|
| 2024-12-17 | 1.0 | 初始版本，包含完整测试环境容器配置 |

## 参考链接

- [nginx-ui](https://github.com/0xJacky/nginx-ui)
- [Nacos Docker](https://nacos.io/docs/latest/quickstart/quick-start-docker/)
- [RocketMQ Docker](https://rocketmq.apache.org/docs/quick-start/02quickstartWithDocker)
- [Grafana Stack](https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/)
- [Elasticsearch Docker](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html)
