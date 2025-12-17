# 企业级多语言平台 - 完整清单

## 快速导航

本文档汇总企业级项目所需的所有组件，标记状态便于检查遗漏。

## 一、基础设施 ✅

| 组件 | 选型 | 状态 | 文档 |
|------|------|------|------|
| K8s 集群 | Kubernetes 1.28+ | ⬜ | [02-INFRASTRUCTURE](02-INFRASTRUCTURE.md) |
| 容器运行时 | Containerd | ⬜ | |
| 网络插件 | Cilium | ⬜ | |
| Ingress | APISIX | ⬜ | |
| 镜像仓库 | Harbor | ⬜ | |
| 对象存储 | MinIO | ⬜ | |
| GitOps | ArgoCD | ⬜ | |

## 二、中间件 ✅

| 组件 | 选型 | 状态 | 文档 |
|------|------|------|------|
| 关系数据库 | MySQL 8.0 + ShardingSphere | ⬜ | [03-MIDDLEWARE](03-MIDDLEWARE.md) |
| 缓存 | Redis Cluster 7.2 | ⬜ | |
| 消息队列 | RocketMQ 5.1 | ⬜ | |
| 搜索引擎 | Elasticsearch 8.x | ⬜ | |
| 配置中心 | Nacos 2.3 | ⬜ | |
| 注册中心 | Nacos 2.3 | ⬜ | |

## 三、微服务框架 ✅

| 组件 | 选型 | 状态 | 文档 |
|------|------|------|------|
| Java 框架 | Spring Boot 3.x + Cloud Alibaba | ⬜ | [04-MICROSERVICE](04-MICROSERVICE.md) |
| Go 框架 | Go-Zero / Kratos | ⬜ | |
| Python 框架 | FastAPI | ⬜ | |
| API 网关 | 自建 (Go) | ⬜ | |
| 限流熔断 | Sentinel | ⬜ | |
| 分布式事务 | Seata | ⬜ | |
| 分布式锁 | Redisson | ⬜ | |
| 分布式ID | Leaf / 雪花算法 | ⬜ | |

## 四、业务支撑 ✅

| 组件 | 说明 | 状态 | 文档 |
|------|------|------|------|
| 用户中心 | 注册/登录/资料 | ⬜ | 05-BUSINESS-SUPPORT |
| 认证授权 | OAuth2 + JWT | ⬜ | |
| 权限管理 | RBAC + 数据权限 | ⬜ | |
| 多租户 | 数据隔离 | ⬜ | |
| 消息中心 | 站内信/WebSocket | ⬜ | |
| 通知服务 | 短信/邮件/IM | ⬜ | |
| 文件服务 | 上传/下载/预览 | ⬜ | |
| 工作流 | Flowable | ⬜ | |

## 五、可观测性 ✅

| 组件 | 选型 | 状态 | 文档 |
|------|------|------|------|
| 采集器 | OTel Collector | ⬜ | [06-OBSERVABILITY](06-OBSERVABILITY.md) |
| 指标存储 | VictoriaMetrics | ⬜ | |
| 日志存储 | Grafana Loki | ⬜ | |
| 链路存储 | Grafana Tempo | ⬜ | |
| 可视化 | Grafana | ⬜ | |
| 告警路由 | AlertManager | ⬜ | |
| 告警中心 | 自建 | ⬜ | |

## 六、安全体系 ✅

| 组件 | 说明 | 状态 | 文档 |
|------|------|------|------|
| WAF | Web 应用防火墙 | ⬜ | [07-SECURITY](07-SECURITY.md) |
| 数据脱敏 | 手机号/身份证/银行卡 | ⬜ | |
| 数据加密 | AES/国密 | ⬜ | |
| 接口签名 | HMAC-SHA256 | ⬜ | |
| 审计日志 | 操作/登录/数据 | ⬜ | |
| 密钥管理 | Vault (可选) | ⬜ | |

## 七、研发效能 ✅

| 组件 | 选型 | 状态 | 文档 |
|------|------|------|------|
| 代码仓库 | GitLab | ⬜ | 08-DEVOPS |
| CI | GitLab CI | ⬜ | |
| CD | ArgoCD | ⬜ | |
| 代码质量 | SonarQube | ⬜ | |
| 制品库 | Nexus + Harbor | ⬜ | |
| API 文档 | Knife4j | ⬜ | |

## 八、运维平台 ✅

| 组件 | 说明 | 状态 | 文档 |
|------|------|------|------|
| 发布平台 | 灰度/金丝雀/回滚 | ⬜ | 09-OPS-PLATFORM |
| 运维管理 | 服务/实例管理 | ⬜ | |
| 任务调度 | XXL-JOB | ⬜ | |
| 调试工具 | Arthas/远程调试 | ⬜ | |

## 九、老项目兼容 ✅

| 语言/版本 | 方案 | 状态 | 文档 |
|----------|------|------|------|
| Spring Boot 1.x | OTel Agent | ⬜ | [10-LEGACY-COMPAT](10-LEGACY-COMPAT.md) |
| Spring Boot 2.x | OTel Agent | ⬜ | |
| Python 2.7 | Sidecar | ⬜ | |
| Flask/Django | OTel SDK | ⬜ | |
| Go 老项目 | OTel SDK | ⬜ | |

## 十、文档清单 ✅

| 文档 | 状态 | 说明 |
|------|------|------|
| [00-INDEX](00-INDEX.md) | ✅ | 文档索引 |
| [01-OVERVIEW](01-OVERVIEW.md) | ✅ | 项目总览 |
| [02-INFRASTRUCTURE](02-INFRASTRUCTURE.md) | ✅ | 基础设施 |
| [03-MIDDLEWARE](03-MIDDLEWARE.md) | ✅ | 中间件 |
| [04-MICROSERVICE](04-MICROSERVICE.md) | ✅ | 微服务框架 |
| 05-BUSINESS-SUPPORT | ⬜ | 业务支撑 |
| [06-OBSERVABILITY](06-OBSERVABILITY.md) | ✅ | 可观测性 |
| [07-SECURITY](07-SECURITY.md) | ✅ | 安全体系 |
| 08-DEVOPS | ⬜ | 研发效能 |
| 09-OPS-PLATFORM | ⬜ | 运维平台 |
| [10-LEGACY-COMPAT](10-LEGACY-COMPAT.md) | ✅ | 老项目兼容 |
| [11-IMPLEMENTATION-PLAN](11-IMPLEMENTATION-PLAN.md) | ✅ | 实施计划 |

## 实施优先级

### P0 - 必须有（上线前）

```
基础设施: K8s + Harbor + GitLab CI
中间件: MySQL + Redis + Nacos + RocketMQ
框架: 公共库 + Starters + 网关
可观测: 监控 + 日志 + 链路
安全: 认证 + 权限 + 脱敏
```

### P1 - 应该有（上线后 1-3 月）

```
业务支撑: 用户/权限/租户/消息/文件
运维平台: 发布/运维/告警
老项目: 容器化 + 接入
```

### P2 - 可以有（3-6 月）

```
高级功能: 服务网格 + 混沌工程 + 全链路压测
效能工具: API 平台 + 低代码
```

## 下一步

1. **确认范围**: 根据实际需求调整组件清单
2. **制定计划**: 参考 [11-IMPLEMENTATION-PLAN](11-IMPLEMENTATION-PLAN.md)
3. **分配任务**: 按阶段分配到团队
4. **开始实施**: Phase 1 基础设施优先
