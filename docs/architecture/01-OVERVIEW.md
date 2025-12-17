# 01 - 项目总览

## 一、架构全景图

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        企业级多语言平台架构                                           │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                     流量入口层                                               │   │
│  │  DNS → CDN → WAF → SLB(双机房) → Ingress Controller → API Gateway                          │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                                      │
│  ┌───────────────────────────────────────────┴─────────────────────────────────────────────────┐   │
│  │                                     应用服务层                                               │   │
│  ├─────────────────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                             │   │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │   │    Java     │  │     Go      │  │   Python    │  │   管理后台   │  │   定时任务   │     │   │
│  │   │  Services   │  │  Services   │  │  Services   │  │    (Vue)    │  │  (XXL-JOB)  │     │   │
│  │   │             │  │             │  │             │  │             │  │             │     │   │
│  │   │ Spring Boot │  │  Go-Zero    │  │   FastAPI   │  │             │  │             │     │   │
│  │   │ 3.x/2.x/1.x │  │  Gin/Kratos │  │   Django    │  │             │  │             │     │   │
│  │   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  │                                                                                             │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                                      │
│  ┌───────────────────────────────────────────┴─────────────────────────────────────────────────┐   │
│  │                                     业务支撑层                                               │   │
│  ├─────────────────────────────────────────────────────────────────────────────────────────────┤   │
│  │  用户中心 │ 权限中心 │ 租户中心 │ 消息中心 │ 文件中心 │ 支付中心 │ 工作流引擎              │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                                      │
│  ┌───────────────────────────────────────────┴─────────────────────────────────────────────────┐   │
│  │                                     中间件层                                                 │   │
│  ├─────────────────────────────────────────────────────────────────────────────────────────────┤   │
│  │  MySQL      │ Redis       │ RocketMQ    │ Elasticsearch │ MinIO      │ Nacos              │   │
│  │  (主从/分片) │ (Cluster)   │ (Cluster)   │ (Cluster)     │ (S3兼容)   │ (配置/注册)        │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                                      │
│  ┌───────────────────────────────────────────┴─────────────────────────────────────────────────┐   │
│  │                                     可观测性层                                               │   │
│  ├─────────────────────────────────────────────────────────────────────────────────────────────┤   │
│  │  VictoriaMetrics │ Grafana Loki │ Grafana Tempo │ Grafana │ AlertManager │ 告警中心        │   │
│  │  (Metrics)       │ (Logs)       │ (Traces)      │ (可视化) │ (告警路由)    │ (自建)         │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                              │                                                      │
│  ┌───────────────────────────────────────────┴─────────────────────────────────────────────────┐   │
│  │                                     基础设施层                                               │   │
│  ├─────────────────────────────────────────────────────────────────────────────────────────────┤   │
│  │  K8s Cluster    │ Harbor      │ GitLab      │ ArgoCD      │ Vault       │ 对象存储         │   │
│  │  (双机房)       │ (镜像仓库)   │ (代码仓库)   │ (GitOps)    │ (密钥管理)   │ (S3/MinIO)      │   │
│  └─────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                     研发运维平台                                                    │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │  发布平台   │ │  运维平台   │ │  告警平台   │ │  API 平台   │ │  测试平台   │ │  调试平台   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、技术选型总表

### 2.1 编程语言 & 框架

| 语言 | 版本 | 主框架 | 兼容版本 | 场景 |
|------|------|--------|---------|------|
| **Java** | 21/17/11/8 | Spring Boot 3.2 | 2.x, 1.x | 主力业务服务 |
| **Go** | 1.21+ | Go-Zero / Kratos | Gin | 高性能服务、网关 |
| **Python** | 3.11+ | FastAPI | Django, Flask | AI/ML、数据处理、脚本 |

### 2.2 基础设施

| 组件 | 选型 | 版本 | 部署方式 | 备注 |
|------|------|------|---------|------|
| 容器编排 | Kubernetes | 1.28+ | 双机房集群 | 生产级 |
| 容器运行时 | Containerd | 1.7+ | 节点部署 | |
| 镜像仓库 | Harbor | 2.9+ | HA 部署 | 双机房同步 |
| 网络插件 | Cilium | 1.14+ | DaemonSet | eBPF 高性能 |
| Ingress | APISIX | 3.6+ | Deployment | 支持多协议 |
| 服务网格 | Istio | 1.20+ | 可选 | 复杂场景 |

### 2.3 中间件

| 组件 | 选型 | 版本 | 集群规模 | 备注 |
|------|------|------|---------|------|
| 关系数据库 | MySQL | 8.0+ | 主从 + 分片 | ShardingSphere |
| 缓存 | Redis | 7.2+ | Cluster 6节点 | 双机房 |
| 消息队列 | RocketMQ | 5.1+ | 双主双从 | 支持事务消息 |
| 搜索引擎 | Elasticsearch | 8.11+ | 3节点+ | 可选 OpenSearch |
| 配置中心 | Nacos | 2.3+ | 3节点 | 配置 + 注册 |
| 对象存储 | MinIO | Latest | 分布式 | S3 兼容 |
| 密钥管理 | Vault | 1.15+ | HA | 可选 |

### 2.4 可观测性

| 组件 | 选型 | 用途 | 备注 |
|------|------|------|------|
| 指标采集 | OTel Collector | 统一采集 | Metrics/Traces/Logs |
| 指标存储 | VictoriaMetrics | 时序数据库 | 高压缩、高性能 |
| 日志存储 | Grafana Loki | 日志聚合 | 低成本 |
| 链路存储 | Grafana Tempo | 分布式追踪 | 无索引 |
| 可视化 | Grafana | Dashboard | 统一入口 |
| 告警 | AlertManager + 自建 | 告警管理 | 多渠道通知 |

### 2.5 研发效能

| 组件 | 选型 | 用途 | 备注 |
|------|------|------|------|
| 代码仓库 | GitLab | 代码管理 | 自建或 SaaS |
| CI | GitLab CI | 持续集成 | Pipeline |
| CD | ArgoCD | 持续部署 | GitOps |
| 制品库 | Nexus + Harbor | Maven/npm/镜像 | |
| 代码质量 | SonarQube | 静态扫描 | |
| API 文档 | Knife4j | 接口文档 | Swagger 增强 |

## 三、项目目录结构

```
enterprise-platform/
├── docs/                           # 文档
│   ├── architecture/               # 架构设计文档
│   ├── api/                        # API 文档
│   └── guides/                     # 开发指南
│
├── infrastructure/                 # 基础设施
│   ├── terraform/                  # IaC 基础设施代码
│   ├── kubernetes/                 # K8s 资源配置
│   │   ├── base/                   # 基础配置
│   │   ├── overlays/               # 环境差异配置
│   │   │   ├── dev/
│   │   │   ├── staging/
│   │   │   └── prod/
│   │   └── argocd/                 # ArgoCD 应用配置
│   ├── helm-charts/                # Helm Charts
│   │   ├── common/                 # 公共 Chart
│   │   ├── java-service/           # Java 服务 Chart
│   │   ├── go-service/             # Go 服务 Chart
│   │   └── python-service/         # Python 服务 Chart
│   └── scripts/                    # 运维脚本
│
├── platform-framework/             # 平台框架（公共库）
│   │
│   ├── java/                       # Java 公共库
│   │   ├── platform-common/        # 公共模块
│   │   │   ├── platform-common-core/       # 核心工具
│   │   │   ├── platform-common-web/        # Web 相关
│   │   │   ├── platform-common-security/   # 安全相关
│   │   │   ├── platform-common-mybatis/    # MyBatis 增强
│   │   │   ├── platform-common-redis/      # Redis 封装
│   │   │   ├── platform-common-mq/         # 消息队列
│   │   │   └── platform-common-log/        # 日志规范
│   │   │
│   │   ├── platform-starters/      # Spring Boot Starters
│   │   │   ├── platform-starter-web/       # Web Starter
│   │   │   ├── platform-starter-security/  # 安全 Starter
│   │   │   ├── platform-starter-mybatis/   # MyBatis Starter
│   │   │   ├── platform-starter-redis/     # Redis Starter
│   │   │   ├── platform-starter-mq/        # MQ Starter
│   │   │   ├── platform-starter-otel/      # 可观测性 Starter
│   │   │   └── platform-starter-job/       # 任务调度 Starter
│   │   │
│   │   └── platform-dependencies/  # 依赖管理 BOM
│   │
│   ├── go/                         # Go 公共库
│   │   ├── pkg/                    # 公共包
│   │   │   ├── config/             # 配置管理
│   │   │   ├── logger/             # 日志
│   │   │   ├── middleware/         # 中间件
│   │   │   ├── response/           # 统一响应
│   │   │   ├── errors/             # 错误处理
│   │   │   ├── database/           # 数据库
│   │   │   ├── cache/              # 缓存
│   │   │   ├── mq/                 # 消息队列
│   │   │   └── trace/              # 链路追踪
│   │   └── go.mod
│   │
│   └── python/                     # Python 公共库
│       ├── platform_common/        # 公共模块
│       │   ├── config/             # 配置
│       │   ├── logging/            # 日志
│       │   ├── response/           # 响应
│       │   ├── middleware/         # 中间件
│       │   ├── database/           # 数据库
│       │   ├── cache/              # 缓存
│       │   └── trace/              # 链路追踪
│       ├── pyproject.toml
│       └── setup.py
│
├── platform-gateway/               # API 网关
│   ├── gateway-core/               # 网关核心（Go）
│   └── gateway-admin/              # 网关管理后台
│
├── platform-services/              # 平台基础服务
│   │
│   ├── auth-service/               # 认证服务 (Java)
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── pom.xml
│   │
│   ├── user-service/               # 用户服务 (Java)
│   ├── tenant-service/             # 租户服务 (Java)
│   ├── permission-service/         # 权限服务 (Java)
│   ├── message-service/            # 消息服务 (Java)
│   ├── file-service/               # 文件服务 (Go)
│   ├── notification-service/       # 通知服务 (Go)
│   └── workflow-service/           # 工作流服务 (Java)
│
├── platform-admin/                 # 管理后台
│   ├── admin-backend/              # 后端 (Java)
│   └── admin-frontend/             # 前端 (Vue3)
│
├── platform-ops/                   # 运维平台
│   ├── ops-backend/                # 后端 (Go)
│   ├── ops-frontend/               # 前端 (Vue3)
│   ├── alert-center/               # 告警中心
│   ├── deploy-center/              # 发布中心
│   └── debug-center/               # 调试中心
│
├── platform-tools/                 # 工具集
│   ├── code-generator/             # 代码生成器
│   ├── db-migration/               # 数据库迁移
│   └── data-sync/                  # 数据同步
│
├── business-services/              # 业务服务（示例）
│   ├── order-service/              # 订单服务 (Java)
│   ├── product-service/            # 商品服务 (Java)
│   ├── inventory-service/          # 库存服务 (Go)
│   ├── search-service/             # 搜索服务 (Python)
│   └── recommend-service/          # 推荐服务 (Python)
│
├── legacy-services/                # 老项目（待迁移）
│   ├── legacy-java-1x/             # Spring Boot 1.x 项目
│   ├── legacy-java-2x/             # Spring Boot 2.x 项目
│   ├── legacy-python/              # Python 2.x 项目
│   └── legacy-go/                  # 老 Go 项目
│
└── docker-compose/                 # 本地开发环境
    ├── docker-compose.yml
    ├── docker-compose.middleware.yml
    └── docker-compose.observability.yml
```

## 四、服务拆分

### 4.1 服务清单

| 服务名 | 语言 | 职责 | 依赖 |
|--------|------|------|------|
| **platform-gateway** | Go | API 网关、路由、限流、认证 | Redis, Nacos |
| **auth-service** | Java | 认证、OAuth2、Token | MySQL, Redis |
| **user-service** | Java | 用户管理、登录、资料 | MySQL, Redis |
| **tenant-service** | Java | 租户管理、配额 | MySQL |
| **permission-service** | Java | RBAC、数据权限、菜单 | MySQL, Redis |
| **message-service** | Java | 站内信、WebSocket | MySQL, Redis, RocketMQ |
| **notification-service** | Go | 短信、邮件、IM推送 | RocketMQ |
| **file-service** | Go | 文件上传、下载、预览 | MinIO |
| **workflow-service** | Java | 工作流、审批 | MySQL |
| **job-service** | Java | 定时任务调度 | MySQL, Redis |

### 4.2 服务通信

```
┌─────────────────────────────────────────────────────────────────────┐
│                          通信方式                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  同步调用:                                                          │
│  ┌─────────┐    HTTP/gRPC    ┌─────────┐                          │
│  │ Service │ ──────────────▶ │ Service │                          │
│  │    A    │                 │    B    │                          │
│  └─────────┘                 └─────────┘                          │
│                                                                     │
│  - Java ↔ Java: OpenFeign (HTTP) / Dubbo 3 (Triple)               │
│  - Java ↔ Go: gRPC                                                 │
│  - Java ↔ Python: gRPC / HTTP                                      │
│  - Go ↔ Python: gRPC / HTTP                                        │
│                                                                     │
│  异步调用:                                                          │
│  ┌─────────┐    Produce     ┌──────────┐    Consume    ┌─────────┐│
│  │ Service │ ─────────────▶ │ RocketMQ │ ────────────▶ │ Service ││
│  │    A    │                └──────────┘               │    B    ││
│  └─────────┘                                           └─────────┘│
│                                                                     │
│  - 事务消息: 订单创建 → 库存扣减                                    │
│  - 延迟消息: 订单超时取消                                           │
│  - 广播消息: 配置变更通知                                           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 五、多语言统一规范

### 5.1 API 规范

```yaml
# 统一响应格式
Response:
  code: 0           # 0=成功，其他=错误码
  message: "success"
  data: {}          # 业务数据
  traceId: "xxx"    # 链路追踪 ID
  timestamp: 1234567890

# 错误码规范
# 1xxxxx - 通用错误
# 2xxxxx - 用户相关
# 3xxxxx - 权限相关
# 4xxxxx - 业务相关
# 5xxxxx - 系统错误
```

### 5.2 日志规范

```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "level": "INFO",
  "service": "order-service",
  "traceId": "abc123",
  "spanId": "def456",
  "requestId": "req-uuid",
  "userId": "U10001",
  "tenantId": "T001",
  "clientIp": "192.168.1.100",
  "message": "订单创建成功",
  "biz": {
    "action": "CREATE_ORDER",
    "orderId": "ORD001"
  }
}
```

### 5.3 配置规范

```yaml
# 所有服务统一配置结构
server:
  port: 8080

app:
  name: order-service
  env: ${ENV:dev}

nacos:
  server-addr: nacos:8848
  namespace: ${NACOS_NAMESPACE}

database:
  host: ${DB_HOST:mysql}
  port: ${DB_PORT:3306}

redis:
  host: ${REDIS_HOST:redis}
  port: ${REDIS_PORT:6379}

otel:
  endpoint: ${OTEL_ENDPOINT:otel-collector:4317}
```

## 六、环境规划

| 环境 | 用途 | K8s Namespace | 数据库 | 说明 |
|------|------|---------------|--------|------|
| **dev** | 开发联调 | dev | 共享 dev 库 | 可随时重建 |
| **test** | 测试验证 | test | 独立 test 库 | 每日自动重置 |
| **staging** | 预发布 | staging | 生产库只读副本 | 接近生产 |
| **prod-a** | 生产机房A | prod | 生产库 | 双活 |
| **prod-b** | 生产机房B | prod | 生产库 | 双活 |

## 七、性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| QPS | 1000万 | 网关层面 |
| 服务数量 | 500+ | 支持大规模 |
| P99 延迟 | < 100ms | 核心接口 |
| 可用性 | 99.99% | 全年停机 < 53分钟 |
| 日志保留 | 1年 | 可归档 |
| 指标保留 | 1年 | 自动降采样 |
| Trace 保留 | 1年 | 采样存储 |
