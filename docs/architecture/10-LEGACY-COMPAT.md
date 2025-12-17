# 10 - 老项目兼容方案

## 一、兼容策略总览

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              老项目兼容策略                                          │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           核心原则                                           │   │
│  │                                                                             │   │
│  │   1. 渐进式迁移 - 不要求一次性全部改造                                       │   │
│  │   2. 统一接入层 - 网关统一入口，内部逐步升级                                 │   │
│  │   3. 可观测统一 - 日志/监控/链路统一接入                                     │   │
│  │   4. 配置统一 - 逐步迁移到 Nacos                                            │   │
│  │   5. 容器化优先 - 优先解决部署问题                                           │   │
│  │                                                                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           迁移路径                                           │   │
│  │                                                                             │   │
│  │   Phase 1: 容器化部署（不改代码）                                            │   │
│  │      │                                                                      │   │
│  │      ▼                                                                      │   │
│  │   Phase 2: 可观测性接入（OTel Agent）                                       │   │
│  │      │                                                                      │   │
│  │      ▼                                                                      │   │
│  │   Phase 3: 网关统一接入                                                     │   │
│  │      │                                                                      │   │
│  │      ▼                                                                      │   │
│  │   Phase 4: 配置中心迁移                                                     │   │
│  │      │                                                                      │   │
│  │      ▼                                                                      │   │
│  │   Phase 5: 框架升级（可选）                                                 │   │
│  │                                                                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、Java 老项目兼容

### 2.1 Spring Boot 版本兼容矩阵

| Spring Boot | Java | 可观测方案 | 配置方案 | 迁移难度 |
|-------------|------|-----------|---------|---------|
| 3.x | 17/21 | OTel Starter | 原生支持 | 无需迁移 |
| 2.7.x | 8/11/17 | OTel Agent | Nacos 2.x | ⭐ |
| 2.0-2.6 | 8/11 | OTel Agent | Nacos 2.x | ⭐⭐ |
| 1.5.x | 8 | OTel Agent | Nacos 1.x 兼容 | ⭐⭐⭐ |
| 1.0-1.4 | 7/8 | OTel Agent | 配置文件 | ⭐⭐⭐⭐ |

### 2.2 Spring Boot 1.x 兼容方案

#### Dockerfile - 无需改代码

```dockerfile
# 适用于 Spring Boot 1.x
FROM eclipse-temurin:8-jre

# 下载 OTel Java Agent（支持 Java 8+）
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.10.0/opentelemetry-javaagent.jar /opt/otel-agent.jar

WORKDIR /app

COPY target/*.jar app.jar

# 环境变量配置
ENV JAVA_OPTS=""
ENV OTEL_SERVICE_NAME="legacy-service"
ENV OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector:4317"
ENV OTEL_LOGS_EXPORTER="otlp"
ENV OTEL_METRICS_EXPORTER="otlp"
ENV OTEL_TRACES_EXPORTER="otlp"

# 启动命令 - 挂载 OTel Agent
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -javaagent:/opt/otel-agent.jar -jar app.jar"]
```

#### K8s 部署配置

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-java-1x
  labels:
    app: legacy-java-1x
    version: v1
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: app
          image: harbor.example.com/legacy/legacy-java-1x:1.0.0
          ports:
            - containerPort: 8080
          env:
            # 服务标识
            - name: OTEL_SERVICE_NAME
              value: "legacy-java-1x"
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "service.namespace=legacy,deployment.environment=prod"
            # OTel Collector 地址
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector.monitoring:4317"
            # 采样率
            - name: OTEL_TRACES_SAMPLER
              value: "parentbased_traceidratio"
            - name: OTEL_TRACES_SAMPLER_ARG
              value: "0.1"
            # 原有配置（保持不变）
            - name: SPRING_PROFILES_ACTIVE
              value: "prod"
            - name: SERVER_PORT
              value: "8080"
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: 2
              memory: 2Gi
          # 健康检查
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 5
```

### 2.3 Spring Boot 2.x 兼容方案

#### 方案一：OTel Agent（推荐，零代码改动）

同 1.x 方案，只需要换基础镜像：

```dockerfile
FROM eclipse-temurin:11-jre  # 或 17-jre
# 其余同 1.x
```

#### 方案二：引入兼容 Starter（可选，更多控制）

```xml
<!-- pom.xml - Spring Boot 2.x -->
<dependencyManagement>
    <dependencies>
        <!-- 平台 BOM - 2.x 兼容版本 -->
        <dependency>
            <groupId>com.platform</groupId>
            <artifactId>platform-dependencies-2x</artifactId>
            <version>1.0.0</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>

<dependencies>
    <!-- 兼容 Starter - 自动适配 2.x -->
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-starter-web-2x</artifactId>
    </dependency>

    <!-- Nacos 配置（2.x 兼容版） -->
    <dependency>
        <groupId>com.alibaba.cloud</groupId>
        <artifactId>spring-cloud-starter-alibaba-nacos-config</artifactId>
    </dependency>
</dependencies>
```

```yaml
# bootstrap.yml - Nacos 配置
spring:
  application:
    name: legacy-java-2x
  cloud:
    nacos:
      config:
        server-addr: nacos.middleware:8848
        namespace: ${NACOS_NAMESPACE:dev}
        file-extension: yaml
        shared-configs:
          - data-id: common.yaml
            group: DEFAULT_GROUP
            refresh: true
```

### 2.4 平台兼容 Starter

```java
// platform-starter-web-2x - 适配 Spring Boot 2.x
@Configuration
@ConditionalOnClass(name = "org.springframework.boot.SpringApplication")
@ConditionalOnProperty(name = "spring.boot.version", havingValue = "2", matchIfMissing = true)
public class PlatformWeb2xAutoConfiguration {

    /**
     * 兼容 2.x 的异常处理
     */
    @Bean
    @ConditionalOnMissingBean
    public GlobalExceptionHandler globalExceptionHandler() {
        return new GlobalExceptionHandler();
    }

    /**
     * 兼容 2.x 的日志 Filter
     * 注意：2.x 使用 javax.servlet，3.x 使用 jakarta.servlet
     */
    @Bean
    public FilterRegistrationBean<LogContextFilter> logContextFilter() {
        FilterRegistrationBean<LogContextFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(new LogContextFilter());
        registration.addUrlPatterns("/*");
        registration.setOrder(Ordered.HIGHEST_PRECEDENCE);
        return registration;
    }

    /**
     * 适配 2.x 的响应格式
     */
    @Bean
    public ResponseBodyAdvice<Object> responseWrapper() {
        return new PlatformResponseWrapper();
    }
}
```

## 三、Python 老项目兼容

### 3.1 Python 版本兼容矩阵

| Python | 框架 | 可观测方案 | 迁移难度 |
|--------|------|-----------|---------|
| 3.9+ | FastAPI | OTel SDK | 无需迁移 |
| 3.7-3.8 | FastAPI/Flask | OTel SDK | ⭐ |
| 3.6 | Flask/Django | OTel SDK (旧版) | ⭐⭐ |
| 2.7 | Flask/Django | 无原生支持 | ⭐⭐⭐⭐ |

### 3.2 Python 2.7 兼容方案

Python 2.7 已停止支持，OTel 不支持。采用**边车代理**方案：

```yaml
# K8s Deployment - Sidecar 模式
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-python-2x
spec:
  template:
    spec:
      containers:
        # 老 Python 2.7 应用
        - name: app
          image: harbor.example.com/legacy/legacy-python-2x:1.0.0
          ports:
            - containerPort: 5000
          env:
            - name: FLASK_ENV
              value: "production"

        # Sidecar - Promtail 采集日志
        - name: promtail
          image: grafana/promtail:2.9.0
          args:
            - -config.file=/etc/promtail/promtail.yaml
          volumeMounts:
            - name: logs
              mountPath: /var/log/app
              readOnly: true
            - name: promtail-config
              mountPath: /etc/promtail

        # Sidecar - OTel Collector 采集指标
        - name: otel-collector
          image: otel/opentelemetry-collector:0.91.0
          args:
            - --config=/etc/otel/config.yaml
          volumeMounts:
            - name: otel-config
              mountPath: /etc/otel

      volumes:
        - name: logs
          emptyDir: {}
        - name: promtail-config
          configMap:
            name: legacy-python-promtail-config
        - name: otel-config
          configMap:
            name: legacy-python-otel-config
```

### 3.3 Flask/Django 兼容方案

```python
# 老 Flask 项目添加 OTel 支持
# requirements.txt 添加：
# opentelemetry-api==1.21.0
# opentelemetry-sdk==1.21.0
# opentelemetry-instrumentation-flask==0.42b0
# opentelemetry-exporter-otlp==1.21.0

# app.py - 最小改动
from flask import Flask
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor

app = Flask(__name__)

# 初始化 OTel（添加这段代码即可）
def init_telemetry():
    provider = TracerProvider()
    processor = BatchSpanProcessor(
        OTLPSpanExporter(endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "otel-collector:4317"))
    )
    provider.add_span_processor(processor)
    trace.set_tracer_provider(provider)

    # 自动埋点 Flask
    FlaskInstrumentor().instrument_app(app)

init_telemetry()

# 原有代码保持不变
@app.route('/api/data')
def get_data():
    return jsonify({"status": "ok"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### 3.4 Django 兼容方案

```python
# settings.py - 添加 OTel 配置
INSTALLED_APPS = [
    # ... 原有 apps
]

# OTel 配置
import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.django import DjangoInstrumentor

# 初始化
provider = TracerProvider()
provider.add_span_processor(
    BatchSpanProcessor(
        OTLPSpanExporter(endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "otel-collector:4317"))
    )
)
trace.set_tracer_provider(provider)

# 自动埋点
DjangoInstrumentor().instrument()
```

## 四、Go 老项目兼容

### 4.1 Go 版本兼容

| Go | 框架 | 可观测方案 | 迁移难度 |
|----|------|-----------|---------|
| 1.21+ | Go-Zero/Kratos | OTel SDK | 无需迁移 |
| 1.18-1.20 | Gin/Echo | OTel SDK | ⭐ |
| 1.13-1.17 | Gin | OTel SDK (旧版) | ⭐⭐ |
| < 1.13 | - | 需升级 Go | ⭐⭐⭐ |

### 4.2 Gin 老项目兼容

```go
// 老 Gin 项目添加 OTel 支持
package main

import (
    "github.com/gin-gonic/gin"
    "go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/trace"
)

func initTracer() func() {
    exporter, _ := otlptracegrpc.New(context.Background(),
        otlptracegrpc.WithEndpoint(os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")),
        otlptracegrpc.WithInsecure(),
    )

    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceNameKey.String("legacy-go-service"),
        )),
    )
    otel.SetTracerProvider(tp)

    return func() { tp.Shutdown(context.Background()) }
}

func main() {
    shutdown := initTracer()
    defer shutdown()

    r := gin.Default()

    // 添加 OTel 中间件（仅需这一行）
    r.Use(otelgin.Middleware("legacy-go-service"))

    // 原有路由保持不变
    r.GET("/api/data", getData)

    r.Run(":8080")
}
```

## 五、网关统一接入

### 5.1 老服务网关路由

```yaml
# APISIX 路由配置
routes:
  # 新服务 - 内部 K8s Service
  - uri: /api/v1/orders/*
    upstream:
      type: roundrobin
      nodes:
        order-service.business:8080: 1

  # 老 Java 1.x 服务
  - uri: /api/legacy/users/*
    upstream:
      type: roundrobin
      nodes:
        legacy-java-1x.legacy:8080: 1
    plugins:
      # 添加请求头
      proxy-rewrite:
        headers:
          X-Legacy-Service: "true"
      # 超时设置（老服务可能较慢）
      proxy-timeout:
        connect: 10
        send: 60
        read: 60

  # 老 Python 服务
  - uri: /api/legacy/data/*
    upstream:
      type: roundrobin
      nodes:
        legacy-python.legacy:5000: 1
    plugins:
      # 限流保护
      limit-req:
        rate: 100
        burst: 50
```

### 5.2 服务发现兼容

```yaml
# 老服务注册到 Nacos
# 方案1：应用内注册（需要改代码）
# 方案2：K8s Service 自动发现（推荐）

# APISIX 使用 K8s Service Discovery
apisix:
  discovery:
    kubernetes:
      service:
        host: kubernetes.default.svc
        port: 443
      client:
        token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
```

## 六、配置迁移

### 6.1 配置迁移策略

```
┌─────────────────────────────────────────────────────────────────┐
│                     配置迁移路径                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   阶段 1: 保持现有配置                                          │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  application.properties / application.yml               │  │
│   │  + 环境变量覆盖                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│   阶段 2: 敏感配置迁移到 K8s Secret                             │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  数据库密码、API Key 等 → K8s Secret → 环境变量          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│   阶段 3: 公共配置迁移到 Nacos                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  common.yaml (Nacos) + application.yml (本地)           │  │
│   └─────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│   阶段 4: 全部配置迁移到 Nacos                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  service.yaml (Nacos) + bootstrap.yml (本地最小化)       │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 环境变量覆盖（阶段1）

```yaml
# K8s ConfigMap - 覆盖配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: legacy-java-1x-config
data:
  # 覆盖 Spring Boot 配置
  SERVER_PORT: "8080"
  SPRING_DATASOURCE_URL: "jdbc:mysql://mysql.middleware:3306/legacy"
  SPRING_REDIS_HOST: "redis.middleware"
---
# Deployment 使用
spec:
  containers:
    - name: app
      envFrom:
        - configMapRef:
            name: legacy-java-1x-config
        - secretRef:
            name: legacy-java-1x-secret
```

## 七、数据库兼容

### 7.1 数据源隔离

```
┌─────────────────────────────────────────────────────────────────┐
│                     数据库隔离策略                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   老项目数据库                    新平台数据库                   │
│   ┌─────────────┐                ┌─────────────┐               │
│   │ legacy_db   │                │ platform_db │               │
│   │             │   数据同步      │             │               │
│   │ - users     │ ──────────────▶│ - users     │               │
│   │ - orders    │   (可选)       │ - orders    │               │
│   └─────────────┘                └─────────────┘               │
│                                                                 │
│   策略:                                                         │
│   1. 老项目继续使用老库，直到下线                                │
│   2. 新功能使用新库                                             │
│   3. 需要共享的数据通过 API/消息同步                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 数据同步方案

```java
// 使用 Canal 监听老库变更，同步到新库
@Component
public class LegacyDataSyncListener {

    @Autowired
    private UserService userService;

    @RocketMQMessageListener(topic = "canal-legacy-users", consumerGroup = "sync-group")
    public class UserSyncConsumer implements RocketMQListener<CanalMessage> {

        @Override
        public void onMessage(CanalMessage message) {
            if ("INSERT".equals(message.getType()) || "UPDATE".equals(message.getType())) {
                // 同步到新库
                LegacyUser legacyUser = parseUser(message.getData());
                userService.syncFromLegacy(legacyUser);
            }
        }
    }
}
```

## 八、迁移检查清单

### 8.1 容器化检查

- [ ] Dockerfile 编写完成
- [ ] 健康检查端点 `/health` 可用
- [ ] 日志输出到 stdout
- [ ] 配置可通过环境变量覆盖
- [ ] 无状态设计（或状态外置）
- [ ] 优雅停机支持

### 8.2 可观测性检查

- [ ] OTel Agent 挂载（Java/Go）
- [ ] OTel SDK 集成（Python）
- [ ] 日志格式统一（JSON 或可解析）
- [ ] 关键业务指标暴露
- [ ] 健康检查指标

### 8.3 网络检查

- [ ] 服务端口确认
- [ ] 内部依赖 DNS 解析
- [ ] 网关路由配置
- [ ] 超时配置合理

### 8.4 安全检查

- [ ] 敏感配置不在镜像中
- [ ] 数据库密码使用 Secret
- [ ] API 认证对接（如需要）

## 九、迁移时间线示例

```
Week 1-2: 准备阶段
├── 梳理老项目清单
├── 确定优先级
├── 编写 Dockerfile
└── 本地测试

Week 3-4: 容器化部署
├── 部署到 K8s（dev 环境）
├── 健康检查验证
├── 基础监控接入
└── 功能验证

Week 5-6: 可观测性
├── OTel Agent/SDK 接入
├── 日志采集验证
├── 链路追踪验证
└── Dashboard 配置

Week 7-8: 网关接入
├── 路由配置
├── 流量切换
├── 灰度验证
└── 全量上线

Week 9+: 持续优化
├── 配置迁移到 Nacos
├── 性能优化
├── 告警配置
└── 框架升级（可选）
```
