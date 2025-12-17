# 日志流转归档与流程监控看板

> 解决日志量大（每天数GB）的存储归档问题，以及多服务耦合流程的监控、手工触发、补偿机制

## 一、日志流转架构

### 1.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              日志流转架构                                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │  Java App    │  │   Go App     │  │  Python App  │  │  前端/Nginx  │        │
│  │  Logback     │  │   Zap/Slog   │  │  Loguru      │  │  Access Log  │        │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘        │
│         │                 │                 │                 │                 │
│         ▼                 ▼                 ▼                 ▼                 │
│  ┌─────────────────────────────────────────────────────────────────────┐       │
│  │                        日志文件 / stdout                              │       │
│  │              /var/log/apps/{service}/{date}.log                      │       │
│  └─────────────────────────────────┬───────────────────────────────────┘       │
│                                    │                                            │
│                                    ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐       │
│  │                     Promtail / Fluent-bit                            │       │
│  │                    (采集、解析、打标签)                                │       │
│  └────────────────────┬────────────────────┬───────────────────────────┘       │
│                       │                    │                                    │
│           ┌───────────┴───────┐   ┌───────┴────────────┐                       │
│           ▼                   ▼   ▼                    ▼                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                 │
│  │      Loki       │  │     Kafka       │  │   本地轮转       │                 │
│  │   (实时查询)     │  │   (可选缓冲)    │  │   (备份)         │                 │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘                 │
│           │                    │                    │                           │
│           │                    ▼                    │                           │
│           │           ┌─────────────────┐          │                           │
│           │           │  Elasticsearch  │          │                           │
│           │           │  (全文检索)      │          │                           │
│           │           └────────┬────────┘          │                           │
│           │                    │                    │                           │
│           ▼                    ▼                    ▼                           │
│  ┌─────────────────────────────────────────────────────────────────────┐       │
│  │                         归档层 (S3/MinIO/OSS)                        │       │
│  │                    /{year}/{month}/{service}/{date}.log.gz          │       │
│  └─────────────────────────────────────────────────────────────────────┘       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 日志分级策略

| 级别 | 存储位置 | 保留时间 | 查询方式 | 适用场景 |
|------|----------|----------|----------|----------|
| **热数据** | Loki/ES内存 | 3天 | 实时查询 | 问题排查、实时监控 |
| **温数据** | Loki/ES磁盘 | 15天 | 索引查询 | 近期问题分析 |
| **冷数据** | S3/MinIO | 90天 | 下载后查询 | 审计、合规 |
| **归档数据** | 低频存储 | 1年+ | 按需恢复 | 长期保存 |

### 1.3 日志量估算

假设每天每个服务日志量：

| 服务类型 | 单实例日志量/天 | 实例数 | 总量/天 |
|----------|-----------------|--------|---------|
| 网关服务 | 2GB | 2 | 4GB |
| 业务服务 | 500MB | 10 | 5GB |
| 基础服务 | 200MB | 5 | 1GB |
| **合计** | - | 17 | **~10GB/天** |

存储需求估算：
- 热数据（3天）: 30GB
- 温数据（15天）: 150GB (压缩后约50GB)
- 冷数据（90天）: 900GB (压缩后约100GB)

## 二、日志采集配置

### 2.1 应用日志格式标准

**Java (Logback) - logback-spring.xml**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <springProperty scope="context" name="APP_NAME" source="spring.application.name"/>
    <springProperty scope="context" name="APP_ENV" source="spring.profiles.active"/>

    <!-- JSON格式输出，便于解析 -->
    <appender name="JSON_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>/var/log/apps/${APP_NAME}/${APP_NAME}.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>/var/log/apps/${APP_NAME}/${APP_NAME}.%d{yyyy-MM-dd}.log</fileNamePattern>
            <maxHistory>3</maxHistory>
            <totalSizeCap>5GB</totalSizeCap>
        </rollingPolicy>
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeMdcKeyName>traceId</includeMdcKeyName>
            <includeMdcKeyName>spanId</includeMdcKeyName>
            <includeMdcKeyName>userId</includeMdcKeyName>
            <includeMdcKeyName>tenantId</includeMdcKeyName>
            <customFields>{"app":"${APP_NAME}","env":"${APP_ENV}"}</customFields>
        </encoder>
    </appender>

    <!-- 错误日志单独输出 -->
    <appender name="ERROR_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>/var/log/apps/${APP_NAME}/${APP_NAME}-error.log</file>
        <filter class="ch.qos.logback.classic.filter.ThresholdFilter">
            <level>ERROR</level>
        </filter>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>/var/log/apps/${APP_NAME}/${APP_NAME}-error.%d{yyyy-MM-dd}.log</fileNamePattern>
            <maxHistory>30</maxHistory>
        </rollingPolicy>
        <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
    </appender>

    <root level="INFO">
        <appender-ref ref="JSON_FILE"/>
        <appender-ref ref="ERROR_FILE"/>
    </root>
</configuration>
```

**Go (Zap)**:

```go
package logger

import (
    "os"
    "path/filepath"
    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"
    "gopkg.in/natefinch/lumberjack.v2"
)

func NewLogger(serviceName, env string) *zap.Logger {
    // 日志轮转配置
    logFile := &lumberjack.Logger{
        Filename:   filepath.Join("/var/log/apps", serviceName, serviceName+".log"),
        MaxSize:    500, // MB
        MaxBackups: 3,
        MaxAge:     3,   // days
        Compress:   true,
    }

    // JSON编码器
    encoderConfig := zapcore.EncoderConfig{
        TimeKey:        "timestamp",
        LevelKey:       "level",
        NameKey:        "logger",
        CallerKey:      "caller",
        FunctionKey:    zapcore.OmitKey,
        MessageKey:     "message",
        StacktraceKey:  "stacktrace",
        LineEnding:     zapcore.DefaultLineEnding,
        EncodeLevel:    zapcore.LowercaseLevelEncoder,
        EncodeTime:     zapcore.ISO8601TimeEncoder,
        EncodeDuration: zapcore.SecondsDurationEncoder,
        EncodeCaller:   zapcore.ShortCallerEncoder,
    }

    core := zapcore.NewCore(
        zapcore.NewJSONEncoder(encoderConfig),
        zapcore.NewMultiWriteSyncer(
            zapcore.AddSync(logFile),
            zapcore.AddSync(os.Stdout),
        ),
        zap.InfoLevel,
    )

    return zap.New(core).With(
        zap.String("app", serviceName),
        zap.String("env", env),
    )
}
```

### 2.2 Promtail 采集配置

```yaml
# promtail-config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push
    # 批量发送配置
    batchwait: 1s
    batchsize: 1048576  # 1MB
    # 重试配置
    backoff_config:
      min_period: 500ms
      max_period: 5m
      max_retries: 10
    # 外部标签
    external_labels:
      cluster: prod
      datacenter: dc1

scrape_configs:
  # 应用JSON日志
  - job_name: app-json-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: app-logs
          __path__: /var/log/apps/**/*.log
    pipeline_stages:
      # 解析JSON
      - json:
          expressions:
            timestamp: timestamp
            level: level
            message: message
            app: app
            env: env
            traceId: traceId
            spanId: spanId
            userId: userId
            tenantId: tenantId
            logger: logger_name
            thread: thread_name
            exception: stack_trace

      # 提取标签
      - labels:
          level:
          app:
          env:
          traceId:
          tenantId:

      # 设置时间戳
      - timestamp:
          source: timestamp
          format: RFC3339Nano

      # 输出格式
      - output:
          source: message

      # 丢弃DEBUG日志（生产环境）
      - match:
          selector: '{level="debug"}'
          action: drop

  # 错误日志单独处理（更长保留）
  - job_name: app-error-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: error-logs
          __path__: /var/log/apps/**/*-error.log
    pipeline_stages:
      - json:
          expressions:
            timestamp: timestamp
            level: level
            message: message
            app: app
            exception: stack_trace
      - labels:
          app:
      - multiline:
          firstline: '^\{'
          max_wait_time: 3s

  # Nginx访问日志
  - job_name: nginx-access
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx-access
          __path__: /var/log/nginx/access.log
    pipeline_stages:
      - regex:
          expression: '^(?P<remote_addr>[\d\.]+) - (?P<remote_user>\S+) \[(?P<time_local>[^\]]+)\] "(?P<method>\S+) (?P<request>[^"]+)" (?P<status>\d+) (?P<body_bytes_sent>\d+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)" "(?P<request_time>[\d\.]+)"'
      - labels:
          method:
          status:
      - metrics:
          http_request_duration_seconds:
            type: Histogram
            description: "HTTP request duration"
            source: request_time
            config:
              buckets: [0.01, 0.05, 0.1, 0.5, 1, 5, 10]
```

### 2.3 Loki 存储配置

```yaml
# loki-config.yml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: warn

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

# 分块存储配置
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

# 存储配置
storage_config:
  filesystem:
    directory: /loki/chunks
  # 可选：S3后端
  # aws:
  #   s3: s3://access_key:secret_key@region/bucket_name
  #   s3forcepathstyle: true

# 数据保留配置
limits_config:
  # 摄入限制
  ingestion_rate_mb: 32
  ingestion_burst_size_mb: 64
  per_stream_rate_limit: 5MB
  per_stream_rate_limit_burst: 15MB

  # 查询限制
  max_query_parallelism: 32
  max_query_series: 500
  max_entries_limit_per_query: 10000

  # 保留时间
  retention_period: 360h  # 15天热数据

# 压缩器配置
compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
  delete_request_store: filesystem

# 查询前端
query_range:
  align_queries_with_step: true
  max_retries: 5
  cache_results: true
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 500

# 表管理
table_manager:
  retention_deletes_enabled: true
  retention_period: 360h
```

## 三、日志归档方案

### 3.1 归档流程

```
┌─────────────────────────────────────────────────────────────────────┐
│                        日志归档流程                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  每日凌晨 2:00                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 1. 轮转当日日志文件                                           │   │
│  │    service.log → service.2024-01-15.log                     │   │
│  └─────────────────────────┬───────────────────────────────────┘   │
│                            │                                        │
│  每日凌晨 3:00             ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 2. 压缩前一天日志                                             │   │
│  │    service.2024-01-14.log → service.2024-01-14.log.gz       │   │
│  └─────────────────────────┬───────────────────────────────────┘   │
│                            │                                        │
│  每日凌晨 4:00             ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 3. 上传到 S3/MinIO                                           │   │
│  │    → s3://logs/2024/01/service-a/2024-01-14.log.gz         │   │
│  └─────────────────────────┬───────────────────────────────────┘   │
│                            │                                        │
│  每周日凌晨 5:00           ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 4. 清理本地超过7天的压缩日志                                   │   │
│  │    删除 service.2024-01-07.log.gz                           │   │
│  └─────────────────────────┬───────────────────────────────────┘   │
│                            │                                        │
│  每月1号凌晨 6:00          ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 5. 合并上月日志为月度归档                                      │   │
│  │    → s3://logs-archive/2024/01/service-a.tar.gz            │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 归档脚本

**log-archive.sh** (每日运行):

```bash
#!/bin/bash
set -e

# 配置
LOG_BASE_DIR="/var/log/apps"
S3_BUCKET="s3://platform-logs"
MINIO_ENDPOINT="http://minio:9000"
RETENTION_LOCAL_DAYS=7
RETENTION_S3_DAYS=90

# 日期
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)
YEAR=$(date -d "yesterday" +%Y)
MONTH=$(date -d "yesterday" +%m)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 1. 压缩昨天的日志
compress_logs() {
    log "开始压缩 $YESTERDAY 的日志..."

    find "$LOG_BASE_DIR" -name "*.${YESTERDAY}.log" -type f | while read logfile; do
        if [ -f "$logfile" ]; then
            log "压缩: $logfile"
            gzip -9 "$logfile"
        fi
    done

    log "压缩完成"
}

# 2. 上传到 S3/MinIO
upload_to_s3() {
    log "开始上传到 S3..."

    find "$LOG_BASE_DIR" -name "*.${YESTERDAY}.log.gz" -type f | while read gzfile; do
        service_name=$(basename $(dirname "$gzfile"))
        s3_path="${S3_BUCKET}/${YEAR}/${MONTH}/${service_name}/$(basename $gzfile)"

        log "上传: $gzfile → $s3_path"

        # 使用 mc (MinIO Client) 或 aws cli
        mc cp "$gzfile" "$s3_path" --attr "x-amz-storage-class=STANDARD_IA"

        # 或使用 aws cli
        # aws s3 cp "$gzfile" "$s3_path" --storage-class STANDARD_IA
    done

    log "上传完成"
}

# 3. 清理本地旧日志
cleanup_local() {
    log "清理超过 ${RETENTION_LOCAL_DAYS} 天的本地日志..."

    find "$LOG_BASE_DIR" -name "*.log.gz" -type f -mtime +${RETENTION_LOCAL_DAYS} -delete

    log "本地清理完成"
}

# 4. 清理 S3 旧日志
cleanup_s3() {
    log "清理超过 ${RETENTION_S3_DAYS} 天的 S3 日志..."

    # 计算过期日期
    EXPIRE_DATE=$(date -d "-${RETENTION_S3_DAYS} days" +%Y-%m-%d)

    # 使用 S3 生命周期策略更优，这里是备用方案
    # mc rm --recursive --older-than ${RETENTION_S3_DAYS}d "${S3_BUCKET}/"

    log "S3 清理完成"
}

# 5. 生成归档报告
generate_report() {
    log "生成归档报告..."

    REPORT_FILE="/tmp/log-archive-report-${YESTERDAY}.json"

    # 统计压缩后大小
    TOTAL_SIZE=$(find "$LOG_BASE_DIR" -name "*.${YESTERDAY}.log.gz" -type f -exec du -cb {} + | tail -1 | cut -f1)
    FILE_COUNT=$(find "$LOG_BASE_DIR" -name "*.${YESTERDAY}.log.gz" -type f | wc -l)

    cat > "$REPORT_FILE" <<EOF
{
    "date": "${YESTERDAY}",
    "total_files": ${FILE_COUNT},
    "total_size_bytes": ${TOTAL_SIZE:-0},
    "total_size_mb": $(echo "scale=2; ${TOTAL_SIZE:-0}/1024/1024" | bc),
    "s3_bucket": "${S3_BUCKET}",
    "status": "success",
    "timestamp": "$(date -Iseconds)"
}
EOF

    log "报告已生成: $REPORT_FILE"

    # 可选：发送到监控系统
    # curl -X POST "http://monitor/api/log-archive-report" -d @"$REPORT_FILE"
}

# 主流程
main() {
    log "========== 日志归档开始 =========="

    compress_logs
    upload_to_s3
    cleanup_local
    # cleanup_s3  # 建议使用 S3 生命周期策略
    generate_report

    log "========== 日志归档完成 =========="
}

main "$@"
```

**月度归档脚本 log-monthly-archive.sh**:

```bash
#!/bin/bash
set -e

# 上个月
LAST_MONTH=$(date -d "last month" +%Y-%m)
YEAR=$(date -d "last month" +%Y)
MONTH=$(date -d "last month" +%m)

S3_BUCKET="s3://platform-logs"
S3_ARCHIVE_BUCKET="s3://platform-logs-archive"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 合并月度日志
archive_monthly() {
    log "开始合并 ${LAST_MONTH} 月度日志..."

    # 获取所有服务
    services=$(mc ls "${S3_BUCKET}/${YEAR}/${MONTH}/" | awk '{print $NF}' | tr -d '/')

    for service in $services; do
        log "处理服务: $service"

        TEMP_DIR="/tmp/log-archive/${service}"
        mkdir -p "$TEMP_DIR"

        # 下载该服务该月所有日志
        mc cp --recursive "${S3_BUCKET}/${YEAR}/${MONTH}/${service}/" "$TEMP_DIR/"

        # 打包
        ARCHIVE_FILE="${service}-${LAST_MONTH}.tar.gz"
        tar -czf "/tmp/${ARCHIVE_FILE}" -C "$TEMP_DIR" .

        # 上传到归档桶
        mc cp "/tmp/${ARCHIVE_FILE}" "${S3_ARCHIVE_BUCKET}/${YEAR}/${ARCHIVE_FILE}"

        # 清理临时文件
        rm -rf "$TEMP_DIR"
        rm -f "/tmp/${ARCHIVE_FILE}"

        log "服务 $service 归档完成"
    done

    # 可选：删除原始日志
    # mc rm --recursive "${S3_BUCKET}/${YEAR}/${MONTH}/"

    log "月度归档完成"
}

archive_monthly
```

### 3.3 定时任务配置

**Kubernetes CronJob**:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: log-archive-daily
  namespace: platform
spec:
  schedule: "0 3 * * *"  # 每天凌晨3点
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: log-archiver
            image: platform/log-archiver:1.0.0
            command: ["/scripts/log-archive.sh"]
            env:
            - name: S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: access-key
            - name: S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secret-key
            volumeMounts:
            - name: app-logs
              mountPath: /var/log/apps
              readOnly: true
          volumes:
          - name: app-logs
            hostPath:
              path: /var/log/apps
          restartPolicy: OnFailure

---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: log-archive-monthly
  namespace: platform
spec:
  schedule: "0 6 1 * *"  # 每月1号凌晨6点
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: log-archiver
            image: platform/log-archiver:1.0.0
            command: ["/scripts/log-monthly-archive.sh"]
            env:
            - name: S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: access-key
            - name: S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: secret-key
          restartPolicy: OnFailure
```

### 3.4 S3 生命周期策略

```json
{
    "Rules": [
        {
            "ID": "TransitionToIA",
            "Status": "Enabled",
            "Filter": {
                "Prefix": ""
            },
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "Days": 90,
                    "StorageClass": "GLACIER"
                }
            ],
            "Expiration": {
                "Days": 365
            }
        },
        {
            "ID": "DeleteOldVersions",
            "Status": "Enabled",
            "Filter": {
                "Prefix": ""
            },
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 7
            }
        }
    ]
}
```

## 四、流程监控看板

### 4.1 系统架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           流程监控看板架构                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │                           Vue3 前端看板                                  │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │    │
│  │  │ 流程定义 │ │ 实例列表 │ │ 实时监控 │ │ 手工触发 │ │ 补偿中心 │     │    │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘     │    │
│  └────────────────────────────────┬───────────────────────────────────────┘    │
│                                   │                                             │
│                                   ▼                                             │
│  ┌────────────────────────────────────────────────────────────────────────┐    │
│  │                        流程监控服务 (Java/Go)                           │    │
│  │                                                                        │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │    │
│  │  │ 流程引擎    │  │ 实例追踪    │  │ 触发器      │  │ 补偿引擎    │   │    │
│  │  │ ProcessEngine│ │ InstanceTracker│ │ Trigger    │  │ CompensateEngine│  │    │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘   │    │
│  │         │                │                │                │          │    │
│  └─────────┼────────────────┼────────────────┼────────────────┼──────────┘    │
│            │                │                │                │               │
│            ▼                ▼                ▼                ▼               │
│  ┌─────────────────────────────────────────────────────────────────────┐     │
│  │                           数据层                                      │     │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐        │     │
│  │  │  MySQL    │  │  Redis    │  │  RocketMQ │  │  Loki     │        │     │
│  │  │ 流程定义  │  │ 实时状态  │  │ 事件驱动  │  │ 执行日志  │        │     │
│  │  │ 实例记录  │  │ 分布式锁  │  │ 异步通知  │  │ 链路追踪  │        │     │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘        │     │
│  └─────────────────────────────────────────────────────────────────────┘     │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 核心数据模型

```sql
-- 流程定义表
CREATE TABLE `process_definition` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
    `code` VARCHAR(64) NOT NULL COMMENT '流程编码',
    `name` VARCHAR(128) NOT NULL COMMENT '流程名称',
    `description` TEXT COMMENT '流程描述',
    `version` INT DEFAULT 1 COMMENT '版本号',
    `definition_json` JSON NOT NULL COMMENT '流程定义(DAG)',
    `trigger_type` VARCHAR(32) DEFAULT 'MANUAL' COMMENT '触发类型: MANUAL/CRON/EVENT',
    `trigger_config` JSON COMMENT '触发配置',
    `timeout_minutes` INT DEFAULT 60 COMMENT '超时时间(分钟)',
    `retry_policy` JSON COMMENT '重试策略',
    `status` TINYINT DEFAULT 1 COMMENT '状态: 0-禁用 1-启用',
    `created_by` VARCHAR(64),
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_code_version` (`code`, `version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='流程定义表';

-- 流程实例表
CREATE TABLE `process_instance` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
    `instance_no` VARCHAR(64) NOT NULL COMMENT '实例编号',
    `process_code` VARCHAR(64) NOT NULL COMMENT '流程编码',
    `process_version` INT NOT NULL COMMENT '流程版本',
    `trigger_type` VARCHAR(32) NOT NULL COMMENT '触发类型: MANUAL/CRON/EVENT/COMPENSATE',
    `trigger_source` VARCHAR(128) COMMENT '触发来源',
    `business_key` VARCHAR(128) COMMENT '业务关联键',
    `input_params` JSON COMMENT '输入参数',
    `context_data` JSON COMMENT '上下文数据',
    `status` VARCHAR(32) DEFAULT 'PENDING' COMMENT '状态: PENDING/RUNNING/SUCCESS/FAILED/TIMEOUT/CANCELLED',
    `current_step` VARCHAR(64) COMMENT '当前步骤',
    `progress` INT DEFAULT 0 COMMENT '进度百分比',
    `start_time` DATETIME COMMENT '开始时间',
    `end_time` DATETIME COMMENT '结束时间',
    `duration_ms` BIGINT COMMENT '耗时毫秒',
    `error_message` TEXT COMMENT '错误信息',
    `retry_count` INT DEFAULT 0 COMMENT '重试次数',
    `parent_instance_id` BIGINT COMMENT '父实例ID(补偿场景)',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_instance_no` (`instance_no`),
    KEY `idx_process_code` (`process_code`),
    KEY `idx_business_key` (`business_key`),
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='流程实例表';

-- 步骤执行表
CREATE TABLE `step_execution` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
    `instance_id` BIGINT NOT NULL COMMENT '实例ID',
    `step_code` VARCHAR(64) NOT NULL COMMENT '步骤编码',
    `step_name` VARCHAR(128) COMMENT '步骤名称',
    `step_type` VARCHAR(32) NOT NULL COMMENT '步骤类型: SERVICE/HTTP/SCRIPT/CONDITION/PARALLEL',
    `service_name` VARCHAR(128) COMMENT '目标服务',
    `method_name` VARCHAR(128) COMMENT '方法名称',
    `input_data` JSON COMMENT '输入数据',
    `output_data` JSON COMMENT '输出数据',
    `status` VARCHAR(32) DEFAULT 'PENDING' COMMENT '状态: PENDING/RUNNING/SUCCESS/FAILED/SKIPPED',
    `start_time` DATETIME COMMENT '开始时间',
    `end_time` DATETIME COMMENT '结束时间',
    `duration_ms` BIGINT COMMENT '耗时毫秒',
    `error_message` TEXT COMMENT '错误信息',
    `error_stack` TEXT COMMENT '错误堆栈',
    `retry_count` INT DEFAULT 0 COMMENT '重试次数',
    `trace_id` VARCHAR(64) COMMENT '链路追踪ID',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_instance_id` (`instance_id`),
    KEY `idx_status` (`status`),
    KEY `idx_trace_id` (`trace_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='步骤执行表';

-- 补偿记录表
CREATE TABLE `compensate_record` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
    `compensate_no` VARCHAR(64) NOT NULL COMMENT '补偿编号',
    `original_instance_id` BIGINT NOT NULL COMMENT '原实例ID',
    `compensate_instance_id` BIGINT COMMENT '补偿实例ID',
    `compensate_type` VARCHAR(32) NOT NULL COMMENT '补偿类型: RETRY/ROLLBACK/SKIP/MANUAL',
    `compensate_reason` TEXT COMMENT '补偿原因',
    `from_step` VARCHAR(64) COMMENT '从哪个步骤开始',
    `status` VARCHAR(32) DEFAULT 'PENDING' COMMENT '状态: PENDING/RUNNING/SUCCESS/FAILED',
    `operator` VARCHAR(64) COMMENT '操作人',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `executed_at` DATETIME COMMENT '执行时间',
    UNIQUE KEY `uk_compensate_no` (`compensate_no`),
    KEY `idx_original_instance_id` (`original_instance_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='补偿记录表';

-- 触发记录表
CREATE TABLE `trigger_record` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
    `trigger_no` VARCHAR(64) NOT NULL COMMENT '触发编号',
    `process_code` VARCHAR(64) NOT NULL COMMENT '流程编码',
    `trigger_type` VARCHAR(32) NOT NULL COMMENT '触发类型',
    `trigger_time` DATETIME NOT NULL COMMENT '触发时间',
    `trigger_params` JSON COMMENT '触发参数',
    `instance_id` BIGINT COMMENT '生成的实例ID',
    `status` VARCHAR(32) DEFAULT 'SUCCESS' COMMENT '状态: SUCCESS/FAILED',
    `error_message` TEXT COMMENT '错误信息',
    `operator` VARCHAR(64) COMMENT '操作人(手工触发)',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_process_code` (`process_code`),
    KEY `idx_trigger_time` (`trigger_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='触发记录表';
```

### 4.3 流程定义示例

```json
{
    "code": "data-sync-flow",
    "name": "数据同步流程",
    "version": 1,
    "steps": [
        {
            "code": "fetch-source",
            "name": "获取源数据",
            "type": "SERVICE",
            "service": "data-source-service",
            "method": "fetchData",
            "timeout": 300,
            "retry": {
                "maxAttempts": 3,
                "backoffMs": 5000
            },
            "next": ["transform-data"]
        },
        {
            "code": "transform-data",
            "name": "数据转换",
            "type": "SERVICE",
            "service": "data-transform-service",
            "method": "transform",
            "inputMapping": {
                "rawData": "${fetch-source.output.data}"
            },
            "next": ["validate-data"]
        },
        {
            "code": "validate-data",
            "name": "数据校验",
            "type": "SERVICE",
            "service": "data-validate-service",
            "method": "validate",
            "next": ["check-result"]
        },
        {
            "code": "check-result",
            "name": "检查校验结果",
            "type": "CONDITION",
            "condition": "${validate-data.output.valid} == true",
            "onTrue": ["save-data"],
            "onFalse": ["notify-error"]
        },
        {
            "code": "save-data",
            "name": "保存数据",
            "type": "SERVICE",
            "service": "data-storage-service",
            "method": "save",
            "next": ["notify-success"]
        },
        {
            "code": "notify-success",
            "name": "发送成功通知",
            "type": "SERVICE",
            "service": "notification-service",
            "method": "sendSuccess",
            "next": []
        },
        {
            "code": "notify-error",
            "name": "发送失败通知",
            "type": "SERVICE",
            "service": "notification-service",
            "method": "sendError",
            "next": []
        }
    ],
    "startStep": "fetch-source",
    "globalTimeout": 1800,
    "alertConfig": {
        "onTimeout": true,
        "onFailed": true,
        "channels": ["feishu", "email"]
    }
}
```

### 4.4 核心服务实现

**流程引擎核心类**:

```java
package com.platform.process.engine;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class ProcessEngine {

    private final ProcessDefinitionRepository definitionRepo;
    private final ProcessInstanceRepository instanceRepo;
    private final StepExecutionRepository stepRepo;
    private final StepExecutorFactory executorFactory;
    private final ProcessEventPublisher eventPublisher;
    private final RedissonClient redisson;

    /**
     * 启动流程实例
     */
    @Transactional
    public ProcessInstance startProcess(StartProcessRequest request) {
        // 1. 获取流程定义
        ProcessDefinition definition = definitionRepo.findByCode(request.getProcessCode())
            .orElseThrow(() -> new BizException("流程不存在: " + request.getProcessCode()));

        // 2. 创建流程实例
        ProcessInstance instance = ProcessInstance.builder()
            .instanceNo(generateInstanceNo())
            .processCode(definition.getCode())
            .processVersion(definition.getVersion())
            .triggerType(request.getTriggerType())
            .triggerSource(request.getTriggerSource())
            .businessKey(request.getBusinessKey())
            .inputParams(request.getParams())
            .status(ProcessStatus.PENDING)
            .build();

        instanceRepo.save(instance);

        // 3. 初始化步骤
        initStepExecutions(instance, definition);

        // 4. 发布启动事件
        eventPublisher.publish(new ProcessStartedEvent(instance));

        // 5. 异步执行
        executeAsync(instance);

        return instance;
    }

    /**
     * 异步执行流程
     */
    @Async("processExecutor")
    public void executeAsync(ProcessInstance instance) {
        String lockKey = "process:lock:" + instance.getInstanceNo();
        RLock lock = redisson.getLock(lockKey);

        try {
            if (!lock.tryLock(10, 3600, TimeUnit.SECONDS)) {
                log.warn("获取流程锁失败: {}", instance.getInstanceNo());
                return;
            }

            instance.setStatus(ProcessStatus.RUNNING);
            instance.setStartTime(LocalDateTime.now());
            instanceRepo.save(instance);

            ProcessDefinition definition = definitionRepo.findByCodeAndVersion(
                instance.getProcessCode(), instance.getProcessVersion()).get();

            // 执行步骤
            executeSteps(instance, definition);

        } catch (Exception e) {
            log.error("流程执行异常: {}", instance.getInstanceNo(), e);
            instance.setStatus(ProcessStatus.FAILED);
            instance.setErrorMessage(e.getMessage());
            instanceRepo.save(instance);

            eventPublisher.publish(new ProcessFailedEvent(instance, e));
        } finally {
            if (lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }

    /**
     * 执行步骤
     */
    private void executeSteps(ProcessInstance instance, ProcessDefinition definition) {
        ProcessContext context = new ProcessContext(instance);
        String currentStep = definition.getStartStep();

        while (currentStep != null && !currentStep.isEmpty()) {
            StepDefinition stepDef = definition.getStep(currentStep);
            StepExecution execution = stepRepo.findByInstanceIdAndStepCode(
                instance.getId(), currentStep).get();

            try {
                // 更新当前步骤
                instance.setCurrentStep(currentStep);
                instanceRepo.save(instance);

                // 执行步骤
                StepExecutor executor = executorFactory.getExecutor(stepDef.getType());
                StepResult result = executor.execute(stepDef, context, execution);

                // 保存执行结果
                execution.setStatus(result.isSuccess() ? StepStatus.SUCCESS : StepStatus.FAILED);
                execution.setOutputData(result.getOutput());
                execution.setEndTime(LocalDateTime.now());
                execution.setDurationMs(Duration.between(execution.getStartTime(),
                    execution.getEndTime()).toMillis());
                stepRepo.save(execution);

                // 更新上下文
                context.setStepOutput(currentStep, result.getOutput());

                // 计算下一步骤
                if (result.isSuccess()) {
                    currentStep = determineNextStep(stepDef, result, context);
                    updateProgress(instance, definition);
                } else {
                    // 重试或失败
                    if (shouldRetry(stepDef, execution)) {
                        retryStep(instance, execution, stepDef);
                        continue;
                    }
                    throw new StepExecutionException(currentStep, result.getError());
                }

            } catch (Exception e) {
                execution.setStatus(StepStatus.FAILED);
                execution.setErrorMessage(e.getMessage());
                execution.setErrorStack(ExceptionUtils.getStackTrace(e));
                stepRepo.save(execution);
                throw e;
            }
        }

        // 流程完成
        instance.setStatus(ProcessStatus.SUCCESS);
        instance.setEndTime(LocalDateTime.now());
        instance.setDurationMs(Duration.between(instance.getStartTime(),
            instance.getEndTime()).toMillis());
        instance.setProgress(100);
        instanceRepo.save(instance);

        eventPublisher.publish(new ProcessCompletedEvent(instance));
    }

    /**
     * 手工触发
     */
    @Transactional
    public ProcessInstance manualTrigger(ManualTriggerRequest request) {
        log.info("手工触发流程: {}, 操作人: {}", request.getProcessCode(), request.getOperator());

        // 记录触发
        TriggerRecord record = TriggerRecord.builder()
            .triggerNo(generateTriggerNo())
            .processCode(request.getProcessCode())
            .triggerType(TriggerType.MANUAL)
            .triggerTime(LocalDateTime.now())
            .triggerParams(request.getParams())
            .operator(request.getOperator())
            .build();
        triggerRepo.save(record);

        // 启动流程
        StartProcessRequest startRequest = StartProcessRequest.builder()
            .processCode(request.getProcessCode())
            .triggerType(TriggerType.MANUAL)
            .triggerSource("manual:" + request.getOperator())
            .params(request.getParams())
            .build();

        ProcessInstance instance = startProcess(startRequest);

        record.setInstanceId(instance.getId());
        record.setStatus(TriggerStatus.SUCCESS);
        triggerRepo.save(record);

        return instance;
    }

    /**
     * 补偿触发
     */
    @Transactional
    public CompensateRecord compensate(CompensateRequest request) {
        log.info("补偿触发: 原实例={}, 类型={}", request.getOriginalInstanceId(), request.getType());

        ProcessInstance originalInstance = instanceRepo.findById(request.getOriginalInstanceId())
            .orElseThrow(() -> new BizException("原实例不存在"));

        CompensateRecord record = CompensateRecord.builder()
            .compensateNo(generateCompensateNo())
            .originalInstanceId(request.getOriginalInstanceId())
            .compensateType(request.getType())
            .compensateReason(request.getReason())
            .fromStep(request.getFromStep())
            .operator(request.getOperator())
            .status(CompensateStatus.PENDING)
            .build();
        compensateRepo.save(record);

        try {
            ProcessInstance compensateInstance;

            switch (request.getType()) {
                case RETRY:
                    // 从失败步骤重试
                    compensateInstance = retryFromStep(originalInstance, request.getFromStep());
                    break;
                case ROLLBACK:
                    // 回滚并重新执行
                    compensateInstance = rollbackAndRerun(originalInstance);
                    break;
                case SKIP:
                    // 跳过失败步骤继续
                    compensateInstance = skipAndContinue(originalInstance, request.getFromStep());
                    break;
                case MANUAL:
                    // 手工处理后继续
                    compensateInstance = continueAfterManual(originalInstance, request.getFromStep(),
                        request.getManualResult());
                    break;
                default:
                    throw new BizException("不支持的补偿类型");
            }

            record.setCompensateInstanceId(compensateInstance.getId());
            record.setStatus(CompensateStatus.RUNNING);
            record.setExecutedAt(LocalDateTime.now());

        } catch (Exception e) {
            record.setStatus(CompensateStatus.FAILED);
            log.error("补偿执行失败", e);
        }

        compensateRepo.save(record);
        return record;
    }
}
```

### 4.5 前端看板页面

**流程监控主页 ProcessMonitor.vue**:

```vue
<template>
  <div class="process-monitor">
    <!-- 统计卡片 -->
    <el-row :gutter="20" class="stat-cards">
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="stat-item">
            <div class="stat-value">{{ stats.totalToday }}</div>
            <div class="stat-label">今日执行</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="running">
          <div class="stat-item">
            <div class="stat-value">{{ stats.running }}</div>
            <div class="stat-label">运行中</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="success">
          <div class="stat-item">
            <div class="stat-value">{{ stats.successRate }}%</div>
            <div class="stat-label">成功率</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="failed">
          <div class="stat-item">
            <div class="stat-value">{{ stats.failed }}</div>
            <div class="stat-label">失败待处理</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 操作区 -->
    <el-card class="action-bar">
      <el-row :gutter="20">
        <el-col :span="6">
          <el-select v-model="filters.processCode" placeholder="选择流程" clearable>
            <el-option
              v-for="item in processList"
              :key="item.code"
              :label="item.name"
              :value="item.code"
            />
          </el-select>
        </el-col>
        <el-col :span="6">
          <el-select v-model="filters.status" placeholder="状态" clearable>
            <el-option label="运行中" value="RUNNING" />
            <el-option label="成功" value="SUCCESS" />
            <el-option label="失败" value="FAILED" />
            <el-option label="超时" value="TIMEOUT" />
          </el-select>
        </el-col>
        <el-col :span="6">
          <el-date-picker
            v-model="filters.dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
          />
        </el-col>
        <el-col :span="6">
          <el-button type="primary" @click="handleSearch">查询</el-button>
          <el-button type="success" @click="showTriggerDialog">手工触发</el-button>
          <el-button @click="handleRefresh">刷新</el-button>
        </el-col>
      </el-row>
    </el-card>

    <!-- 实例列表 -->
    <el-card class="instance-list">
      <el-table :data="instanceList" v-loading="loading" row-key="id">
        <el-table-column prop="instanceNo" label="实例编号" width="180">
          <template #default="{ row }">
            <el-link type="primary" @click="showDetail(row)">
              {{ row.instanceNo }}
            </el-link>
          </template>
        </el-table-column>
        <el-table-column prop="processCode" label="流程" width="150">
          <template #default="{ row }">
            {{ getProcessName(row.processCode) }}
          </template>
        </el-table-column>
        <el-table-column prop="triggerType" label="触发方式" width="100">
          <template #default="{ row }">
            <el-tag :type="getTriggerTypeTag(row.triggerType)">
              {{ row.triggerType }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="getStatusTag(row.status)">
              {{ row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="currentStep" label="当前步骤" width="150" />
        <el-table-column prop="progress" label="进度" width="150">
          <template #default="{ row }">
            <el-progress
              :percentage="row.progress"
              :status="getProgressStatus(row.status)"
            />
          </template>
        </el-table-column>
        <el-table-column prop="startTime" label="开始时间" width="180" />
        <el-table-column prop="durationMs" label="耗时" width="100">
          <template #default="{ row }">
            {{ formatDuration(row.durationMs) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button size="small" @click="showDetail(row)">详情</el-button>
            <el-button
              v-if="row.status === 'FAILED'"
              size="small"
              type="warning"
              @click="showCompensateDialog(row)"
            >
              补偿
            </el-button>
            <el-button
              v-if="row.status === 'RUNNING'"
              size="small"
              type="danger"
              @click="handleCancel(row)"
            >
              取消
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
        v-model:current-page="pagination.page"
        v-model:page-size="pagination.size"
        :total="pagination.total"
        :page-sizes="[20, 50, 100]"
        layout="total, sizes, prev, pager, next"
        @size-change="handleSearch"
        @current-change="handleSearch"
      />
    </el-card>

    <!-- 手工触发对话框 -->
    <el-dialog v-model="triggerDialogVisible" title="手工触发流程" width="600px">
      <el-form :model="triggerForm" label-width="100px">
        <el-form-item label="选择流程" required>
          <el-select v-model="triggerForm.processCode" placeholder="请选择流程">
            <el-option
              v-for="item in processList"
              :key="item.code"
              :label="item.name"
              :value="item.code"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="业务关联键">
          <el-input v-model="triggerForm.businessKey" placeholder="可选，用于关联业务数据" />
        </el-form-item>
        <el-form-item label="输入参数">
          <el-input
            v-model="triggerForm.paramsJson"
            type="textarea"
            :rows="6"
            placeholder='JSON格式参数，如: {"key": "value"}'
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="triggerDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleTrigger">触发执行</el-button>
      </template>
    </el-dialog>

    <!-- 补偿对话框 -->
    <el-dialog v-model="compensateDialogVisible" title="流程补偿" width="600px">
      <el-form :model="compensateForm" label-width="100px">
        <el-form-item label="原实例">
          {{ currentInstance?.instanceNo }}
        </el-form-item>
        <el-form-item label="失败步骤">
          {{ currentInstance?.currentStep }}
        </el-form-item>
        <el-form-item label="错误信息">
          <el-text type="danger">{{ currentInstance?.errorMessage }}</el-text>
        </el-form-item>
        <el-form-item label="补偿方式" required>
          <el-radio-group v-model="compensateForm.type">
            <el-radio label="RETRY">从失败步骤重试</el-radio>
            <el-radio label="SKIP">跳过失败步骤</el-radio>
            <el-radio label="ROLLBACK">回滚重新执行</el-radio>
            <el-radio label="MANUAL">手工处理后继续</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="补偿原因">
          <el-input v-model="compensateForm.reason" type="textarea" :rows="3" />
        </el-form-item>
        <el-form-item v-if="compensateForm.type === 'MANUAL'" label="手工处理结果">
          <el-input
            v-model="compensateForm.manualResultJson"
            type="textarea"
            :rows="4"
            placeholder="JSON格式的处理结果"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="compensateDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleCompensate">执行补偿</el-button>
      </template>
    </el-dialog>

    <!-- 详情抽屉 -->
    <el-drawer v-model="detailDrawerVisible" title="流程实例详情" size="60%">
      <ProcessInstanceDetail :instance="currentInstance" />
    </el-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onUnmounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import ProcessInstanceDetail from './ProcessInstanceDetail.vue'
import {
  getProcessList,
  getInstanceList,
  getStats,
  manualTrigger,
  compensate,
  cancelInstance
} from '@/api/process'

// 统计数据
const stats = ref({
  totalToday: 0,
  running: 0,
  successRate: 0,
  failed: 0
})

// 筛选条件
const filters = reactive({
  processCode: '',
  status: '',
  dateRange: []
})

// 分页
const pagination = reactive({
  page: 1,
  size: 20,
  total: 0
})

// 数据
const loading = ref(false)
const processList = ref([])
const instanceList = ref([])
const currentInstance = ref(null)

// 对话框
const triggerDialogVisible = ref(false)
const compensateDialogVisible = ref(false)
const detailDrawerVisible = ref(false)

// 表单
const triggerForm = reactive({
  processCode: '',
  businessKey: '',
  paramsJson: ''
})

const compensateForm = reactive({
  type: 'RETRY',
  reason: '',
  manualResultJson: ''
})

// 自动刷新
let refreshTimer: number | null = null

onMounted(async () => {
  await loadProcessList()
  await loadStats()
  await handleSearch()

  // 每30秒自动刷新
  refreshTimer = setInterval(() => {
    loadStats()
    if (filters.status === 'RUNNING') {
      handleSearch()
    }
  }, 30000)
})

onUnmounted(() => {
  if (refreshTimer) {
    clearInterval(refreshTimer)
  }
})

// 加载流程列表
async function loadProcessList() {
  const res = await getProcessList()
  processList.value = res.data
}

// 加载统计
async function loadStats() {
  const res = await getStats()
  stats.value = res.data
}

// 搜索
async function handleSearch() {
  loading.value = true
  try {
    const res = await getInstanceList({
      ...filters,
      page: pagination.page,
      size: pagination.size
    })
    instanceList.value = res.data.records
    pagination.total = res.data.total
  } finally {
    loading.value = false
  }
}

// 刷新
function handleRefresh() {
  loadStats()
  handleSearch()
}

// 显示触发对话框
function showTriggerDialog() {
  triggerForm.processCode = ''
  triggerForm.businessKey = ''
  triggerForm.paramsJson = ''
  triggerDialogVisible.value = true
}

// 手工触发
async function handleTrigger() {
  if (!triggerForm.processCode) {
    ElMessage.warning('请选择流程')
    return
  }

  try {
    let params = {}
    if (triggerForm.paramsJson) {
      params = JSON.parse(triggerForm.paramsJson)
    }

    await manualTrigger({
      processCode: triggerForm.processCode,
      businessKey: triggerForm.businessKey,
      params
    })

    ElMessage.success('触发成功')
    triggerDialogVisible.value = false
    handleSearch()
  } catch (e) {
    ElMessage.error('触发失败: ' + e.message)
  }
}

// 显示补偿对话框
function showCompensateDialog(row: any) {
  currentInstance.value = row
  compensateForm.type = 'RETRY'
  compensateForm.reason = ''
  compensateForm.manualResultJson = ''
  compensateDialogVisible.value = true
}

// 执行补偿
async function handleCompensate() {
  try {
    let manualResult = null
    if (compensateForm.type === 'MANUAL' && compensateForm.manualResultJson) {
      manualResult = JSON.parse(compensateForm.manualResultJson)
    }

    await compensate({
      originalInstanceId: currentInstance.value.id,
      type: compensateForm.type,
      reason: compensateForm.reason,
      fromStep: currentInstance.value.currentStep,
      manualResult
    })

    ElMessage.success('补偿任务已提交')
    compensateDialogVisible.value = false
    handleSearch()
  } catch (e) {
    ElMessage.error('补偿失败: ' + e.message)
  }
}

// 取消实例
async function handleCancel(row: any) {
  await ElMessageBox.confirm('确定要取消该流程实例吗？', '提示', {
    type: 'warning'
  })

  await cancelInstance(row.id)
  ElMessage.success('已取消')
  handleSearch()
}

// 显示详情
function showDetail(row: any) {
  currentInstance.value = row
  detailDrawerVisible.value = true
}

// 工具函数
function getProcessName(code: string) {
  return processList.value.find(p => p.code === code)?.name || code
}

function getStatusTag(status: string) {
  const map: Record<string, string> = {
    PENDING: 'info',
    RUNNING: 'primary',
    SUCCESS: 'success',
    FAILED: 'danger',
    TIMEOUT: 'warning',
    CANCELLED: 'info'
  }
  return map[status] || 'info'
}

function getTriggerTypeTag(type: string) {
  const map: Record<string, string> = {
    MANUAL: 'primary',
    CRON: 'success',
    EVENT: 'warning',
    COMPENSATE: 'danger'
  }
  return map[type] || 'info'
}

function getProgressStatus(status: string) {
  if (status === 'SUCCESS') return 'success'
  if (status === 'FAILED') return 'exception'
  return ''
}

function formatDuration(ms: number | null) {
  if (!ms) return '-'
  if (ms < 1000) return ms + 'ms'
  if (ms < 60000) return (ms / 1000).toFixed(1) + 's'
  return (ms / 60000).toFixed(1) + 'min'
}
</script>

<style scoped lang="scss">
.process-monitor {
  padding: 20px;

  .stat-cards {
    margin-bottom: 20px;

    .stat-item {
      text-align: center;
      padding: 10px;

      .stat-value {
        font-size: 32px;
        font-weight: bold;
      }

      .stat-label {
        font-size: 14px;
        color: #909399;
        margin-top: 5px;
      }
    }

    .running .stat-value { color: #409EFF; }
    .success .stat-value { color: #67C23A; }
    .failed .stat-value { color: #F56C6C; }
  }

  .action-bar {
    margin-bottom: 20px;
  }

  .instance-list {
    :deep(.el-pagination) {
      margin-top: 20px;
      justify-content: flex-end;
    }
  }
}
</style>
```

### 4.6 实时监控 WebSocket

```java
@ServerEndpoint("/ws/process/monitor")
@Component
public class ProcessMonitorWebSocket {

    private static final CopyOnWriteArraySet<Session> sessions = new CopyOnWriteArraySet<>();

    @OnOpen
    public void onOpen(Session session) {
        sessions.add(session);
        log.info("WebSocket连接建立: {}", session.getId());
    }

    @OnClose
    public void onClose(Session session) {
        sessions.remove(session);
        log.info("WebSocket连接关闭: {}", session.getId());
    }

    /**
     * 广播流程状态变更
     */
    public static void broadcastStatusChange(ProcessInstance instance) {
        ProcessStatusMessage message = ProcessStatusMessage.builder()
            .type("STATUS_CHANGE")
            .instanceNo(instance.getInstanceNo())
            .processCode(instance.getProcessCode())
            .status(instance.getStatus().name())
            .currentStep(instance.getCurrentStep())
            .progress(instance.getProgress())
            .timestamp(System.currentTimeMillis())
            .build();

        broadcast(JSON.toJSONString(message));
    }

    /**
     * 广播步骤执行进度
     */
    public static void broadcastStepProgress(StepExecution step) {
        StepProgressMessage message = StepProgressMessage.builder()
            .type("STEP_PROGRESS")
            .instanceId(step.getInstanceId())
            .stepCode(step.getStepCode())
            .status(step.getStatus().name())
            .durationMs(step.getDurationMs())
            .timestamp(System.currentTimeMillis())
            .build();

        broadcast(JSON.toJSONString(message));
    }

    private static void broadcast(String message) {
        sessions.forEach(session -> {
            try {
                session.getBasicRemote().sendText(message);
            } catch (Exception e) {
                log.error("WebSocket发送消息失败", e);
            }
        });
    }
}
```

## 五、告警与通知

### 5.1 告警规则配置

```yaml
# alerting-rules.yml
groups:
  - name: process-alerts
    rules:
      # 流程执行失败
      - alert: ProcessFailed
        expr: increase(process_instance_failed_total[5m]) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "流程执行失败"
          description: "流程 {{ $labels.process_code }} 执行失败，实例: {{ $labels.instance_no }}"

      # 流程执行超时
      - alert: ProcessTimeout
        expr: process_instance_duration_seconds > 1800
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "流程执行超时"
          description: "流程 {{ $labels.process_code }} 执行超过30分钟"

      # 流程积压
      - alert: ProcessBacklog
        expr: process_instance_pending_count > 100
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "流程任务积压"
          description: "待执行流程数量超过100"

      # 日志归档失败
      - alert: LogArchiveFailed
        expr: log_archive_job_status == 0
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "日志归档失败"
          description: "日志归档任务执行失败"

      # 日志存储空间不足
      - alert: LogStorageLow
        expr: (node_filesystem_avail_bytes{mountpoint="/var/log"} / node_filesystem_size_bytes{mountpoint="/var/log"}) * 100 < 20
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "日志存储空间不足"
          description: "日志存储剩余空间不足20%"
```

### 5.2 通知模板

```java
@Service
@RequiredArgsConstructor
public class ProcessNotificationService {

    private final FeishuNotifier feishuNotifier;
    private final EmailNotifier emailNotifier;

    /**
     * 发送流程失败通知
     */
    public void notifyProcessFailed(ProcessInstance instance, String errorMessage) {
        String title = String.format("【流程失败】%s", instance.getProcessCode());

        String content = String.format("""
            **流程执行失败**

            - 流程: %s
            - 实例: %s
            - 触发方式: %s
            - 失败步骤: %s
            - 错误信息: %s
            - 开始时间: %s
            - 失败时间: %s

            [查看详情](%s)
            """,
            instance.getProcessCode(),
            instance.getInstanceNo(),
            instance.getTriggerType(),
            instance.getCurrentStep(),
            errorMessage,
            instance.getStartTime(),
            LocalDateTime.now(),
            getDetailUrl(instance.getInstanceNo())
        );

        // 发送飞书通知
        feishuNotifier.sendMarkdown(title, content);

        // 发送邮件（可选）
        emailNotifier.send(title, content);
    }

    /**
     * 发送补偿完成通知
     */
    public void notifyCompensateCompleted(CompensateRecord record, ProcessInstance instance) {
        String title = String.format("【补偿完成】%s", instance.getProcessCode());

        String content = String.format("""
            **流程补偿已完成**

            - 原实例: %s
            - 补偿方式: %s
            - 补偿结果: %s
            - 操作人: %s
            - 执行时间: %s
            """,
            record.getOriginalInstanceId(),
            record.getCompensateType(),
            record.getStatus(),
            record.getOperator(),
            record.getExecutedAt()
        );

        feishuNotifier.sendMarkdown(title, content);
    }
}
```

## 六、Grafana 看板配置

### 6.1 流程监控 Dashboard JSON

```json
{
  "title": "流程监控看板",
  "panels": [
    {
      "title": "流程执行统计",
      "type": "stat",
      "gridPos": { "x": 0, "y": 0, "w": 6, "h": 4 },
      "targets": [
        {
          "expr": "sum(increase(process_instance_total[24h]))",
          "legendFormat": "今日执行"
        }
      ]
    },
    {
      "title": "运行中实例",
      "type": "stat",
      "gridPos": { "x": 6, "y": 0, "w": 6, "h": 4 },
      "targets": [
        {
          "expr": "sum(process_instance_running_count)",
          "legendFormat": "运行中"
        }
      ]
    },
    {
      "title": "成功率",
      "type": "gauge",
      "gridPos": { "x": 12, "y": 0, "w": 6, "h": 4 },
      "targets": [
        {
          "expr": "sum(rate(process_instance_success_total[24h])) / sum(rate(process_instance_total[24h])) * 100"
        }
      ]
    },
    {
      "title": "失败待处理",
      "type": "stat",
      "gridPos": { "x": 18, "y": 0, "w": 6, "h": 4 },
      "targets": [
        {
          "expr": "sum(process_instance_failed_pending_count)"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "steps": [
              { "value": 0, "color": "green" },
              { "value": 5, "color": "yellow" },
              { "value": 10, "color": "red" }
            ]
          }
        }
      }
    },
    {
      "title": "流程执行趋势",
      "type": "timeseries",
      "gridPos": { "x": 0, "y": 4, "w": 12, "h": 8 },
      "targets": [
        {
          "expr": "sum(rate(process_instance_success_total[5m])) by (process_code)",
          "legendFormat": "{{process_code}} 成功"
        },
        {
          "expr": "sum(rate(process_instance_failed_total[5m])) by (process_code)",
          "legendFormat": "{{process_code}} 失败"
        }
      ]
    },
    {
      "title": "步骤执行耗时",
      "type": "heatmap",
      "gridPos": { "x": 12, "y": 4, "w": 12, "h": 8 },
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(step_execution_duration_seconds_bucket[5m])) by (le, step_code))"
        }
      ]
    },
    {
      "title": "日志存储使用",
      "type": "timeseries",
      "gridPos": { "x": 0, "y": 12, "w": 12, "h": 6 },
      "targets": [
        {
          "expr": "sum(loki_ingester_memory_chunks)",
          "legendFormat": "Loki 内存块"
        },
        {
          "expr": "node_filesystem_avail_bytes{mountpoint='/loki'} / 1024 / 1024 / 1024",
          "legendFormat": "Loki 可用空间(GB)"
        }
      ]
    },
    {
      "title": "日志归档状态",
      "type": "table",
      "gridPos": { "x": 12, "y": 12, "w": 12, "h": 6 },
      "targets": [
        {
          "expr": "log_archive_last_run_timestamp",
          "format": "table"
        }
      ]
    }
  ]
}
```

## 七、部署清单

### 7.1 新增组件

| 组件 | 版本 | 用途 | 资源 |
|------|------|------|------|
| process-engine | 自研 | 流程引擎服务 | 2C 2G |
| process-monitor-ui | 自研 | 流程监控前端 | - |
| log-archiver | 自研 | 日志归档服务 | 0.5C 512M |

### 7.2 依赖组件配置调整

| 组件 | 调整项 |
|------|--------|
| Loki | 增加 retention 配置，设置 15 天 |
| MinIO | 增加日志归档 bucket，配置生命周期 |
| RocketMQ | 增加流程事件 topic |
| MySQL | 增加流程相关表 |

## 八、总结

### 日志流转

1. **采集**: Promtail 统一采集，JSON 格式标准化
2. **存储**: Loki 热数据 15 天，ES 可选全文检索
3. **归档**: 每日压缩上传 S3，按月合并归档
4. **清理**: S3 生命周期策略，90 天转冷存储，1 年过期

### 流程监控

1. **流程定义**: DAG 结构，支持条件分支和并行
2. **手工触发**: Web 界面一键触发，参数可配置
3. **补偿机制**: 重试/跳过/回滚/手工处理四种模式
4. **实时监控**: WebSocket 推送，Grafana 看板

### 存储估算 (每天 10GB 日志)

| 存储层 | 保留时间 | 空间需求 |
|--------|----------|----------|
| 热数据 (Loki) | 15 天 | ~50GB (压缩后) |
| 温数据 (S3 标准) | 90 天 | ~100GB |
| 冷数据 (S3 IA) | 1 年 | ~150GB |
| **总计** | - | **~300GB** |
