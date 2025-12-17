# 06 - 可观测性设计

## 一、可观测性架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              可观测性三大支柱                                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│     Metrics (指标)              Logs (日志)              Traces (链路)              │
│     ┌───────────┐              ┌───────────┐              ┌───────────┐            │
│     │ 数值度量   │              │ 事件记录   │              │ 请求追踪   │            │
│     │ 时序数据   │              │ 上下文     │              │ 调用链路   │            │
│     └─────┬─────┘              └─────┬─────┘              └─────┬─────┘            │
│           │                          │                          │                  │
│           └──────────────────────────┼──────────────────────────┘                  │
│                                      │                                              │
│                                      ▼                                              │
│                         ┌─────────────────────────┐                                │
│                         │   OpenTelemetry         │                                │
│                         │   Collector             │                                │
│                         │   (统一采集)            │                                │
│                         └───────────┬─────────────┘                                │
│                                     │                                              │
│           ┌─────────────────────────┼─────────────────────────┐                   │
│           ▼                         ▼                         ▼                   │
│   ┌───────────────┐        ┌───────────────┐        ┌───────────────┐            │
│   │VictoriaMetrics│        │ Grafana Loki  │        │ Grafana Tempo │            │
│   │  (指标存储)   │        │  (日志存储)   │        │  (链路存储)   │            │
│   └───────┬───────┘        └───────┬───────┘        └───────┬───────┘            │
│           │                        │                        │                     │
│           └────────────────────────┼────────────────────────┘                     │
│                                    ▼                                              │
│                         ┌─────────────────────────┐                               │
│                         │       Grafana           │                               │
│                         │    (统一可视化)         │                               │
│                         └───────────┬─────────────┘                               │
│                                     │                                              │
│                                     ▼                                              │
│                         ┌─────────────────────────┐                               │
│                         │   AlertManager          │                               │
│                         │   + 告警中心            │                               │
│                         └─────────────────────────┘                               │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、OTel Collector 配置

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

  # K8s 指标
  prometheus:
    config:
      scrape_configs:
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true

processors:
  batch:
    timeout: 5s
    send_batch_size: 10000

  memory_limiter:
    check_interval: 1s
    limit_mib: 2000
    spike_limit_mib: 400

  resource:
    attributes:
      - key: cluster
        value: ${CLUSTER_NAME}
        action: upsert

  # 日志租户路由
  attributes/tenant:
    actions:
      - key: loki.tenant
        from_attribute: tenant_id
        action: upsert

exporters:
  # 指标 -> VictoriaMetrics
  prometheusremotewrite:
    endpoint: http://vminsert:8480/insert/0/prometheus/api/v1/write

  # 链路 -> Tempo
  otlp/tempo:
    endpoint: tempo-distributor:4317
    tls:
      insecure: true

  # 日志 -> Loki
  loki:
    endpoint: http://loki-distributor:3100/loki/api/v1/push
    tenant_id: ${loki.tenant}

service:
  pipelines:
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch, resource]
      exporters: [prometheusremotewrite]

    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/tempo]

    logs:
      receivers: [otlp]
      processors: [memory_limiter, attributes/tenant, batch]
      exporters: [loki]
```

## 三、日志规范

### 3.1 统一日志格式

```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "level": "INFO",
  "logger": "com.example.OrderService",
  "thread": "http-nio-8080-exec-1",
  "message": "订单创建成功",

  "service": "order-service",
  "env": "prod",
  "version": "1.2.0",
  "instance": "order-service-7d4f5b-x2k9j",

  "traceId": "abc123def456",
  "spanId": "789xyz",
  "requestId": "req-uuid-123",
  "clientIp": "192.168.1.100",
  "userId": "U10001",
  "tenantId": "T001",

  "biz": {
    "action": "CREATE_ORDER",
    "orderId": "ORD202401150001"
  }
}
```

### 3.2 Java Logback 配置

```xml
<!-- logback-spring.xml -->
<configuration>
    <springProperty name="SERVICE_NAME" source="spring.application.name"/>

    <appender name="JSON_CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <customFields>{"service":"${SERVICE_NAME}","env":"${ENV:-dev}"}</customFields>
            <includeMdcKeyName>traceId</includeMdcKeyName>
            <includeMdcKeyName>spanId</includeMdcKeyName>
            <includeMdcKeyName>requestId</includeMdcKeyName>
            <includeMdcKeyName>clientIp</includeMdcKeyName>
            <includeMdcKeyName>userId</includeMdcKeyName>
            <includeMdcKeyName>tenantId</includeMdcKeyName>
        </encoder>
    </appender>

    <springProfile name="prod,staging">
        <root level="INFO">
            <appender-ref ref="JSON_CONSOLE"/>
        </root>
    </springProfile>
</configuration>
```

## 四、告警规则

```yaml
# alerting-rules.yaml
groups:
  - name: application
    rules:
      # 错误率告警
      - alert: HighErrorRate
        expr: |
          sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m])) by (service)
          /
          sum(rate(http_server_requests_seconds_count[5m])) by (service)
          > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.service }} 错误率过高"
          description: "错误率: {{ $value | humanizePercentage }}"

      # P99 延迟告警
      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            sum(rate(http_server_requests_seconds_bucket[5m])) by (le, service)
          ) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.service }} P99 延迟过高"
          description: "P99: {{ $value | humanizeDuration }}"

  - name: infrastructure
    rules:
      # Pod 重启告警
      - alert: PodRestarting
        expr: increase(kube_pod_container_status_restarts_total[1h]) > 3
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.pod }} 频繁重启"

      # 内存使用率
      - alert: HighMemoryUsage
        expr: |
          container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "容器内存使用率过高"
```

## 五、告警通知

```java
// 告警通知服务
@Service
public class AlertNotificationService {

    @Autowired
    private FeishuNotifier feishuNotifier;

    @Autowired
    private WeComNotifier wecomNotifier;

    @Autowired
    private SmsNotifier smsNotifier;

    public void notify(Alert alert) {
        // 根据严重程度选择通知渠道
        switch (alert.getSeverity()) {
            case "critical":
                // 严重告警：飞书 + 短信 + 电话
                feishuNotifier.send(alert);
                smsNotifier.send(alert);
                phoneNotifier.call(alert);
                break;
            case "warning":
                // 警告：飞书
                feishuNotifier.send(alert);
                break;
            default:
                // 信息：仅记录
                log.info("Alert: {}", alert);
        }
    }
}
```
