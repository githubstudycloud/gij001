# 02 - 基础设施层设计

## 一、双机房 K8s 架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              双机房架构总览                                          │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│                              ┌───────────────┐                                      │
│                              │   全局 DNS    │                                      │
│                              │   (智能解析)   │                                      │
│                              └───────┬───────┘                                      │
│                                      │                                              │
│                    ┌─────────────────┴─────────────────┐                           │
│                    │                                   │                           │
│           ┌────────▼────────┐                ┌────────▼────────┐                   │
│           │   机房 A (主)    │                │   机房 B (备)    │                   │
│           │   北京/上海     │                │   广州/深圳     │                   │
│           └────────┬────────┘                └────────┬────────┘                   │
│                    │                                   │                           │
│  ┌─────────────────┼───────────────┐  ┌──────────────┼───────────────┐            │
│  │                 │               │  │              │               │            │
│  │    ┌────────────▼───────────┐   │  │  ┌──────────▼───────────┐   │            │
│  │    │      SLB (入口)        │   │  │  │      SLB (入口)      │   │            │
│  │    └────────────┬───────────┘   │  │  └──────────┬───────────┘   │            │
│  │                 │               │  │             │               │            │
│  │    ┌────────────▼───────────┐   │  │  ┌──────────▼───────────┐   │            │
│  │    │   K8s Cluster A        │   │  │  │   K8s Cluster B      │   │            │
│  │    │   ├── Master x 3       │   │  │  │   ├── Master x 3     │   │            │
│  │    │   ├── Worker x N       │   │  │  │   ├── Worker x N     │   │            │
│  │    │   └── Ingress          │   │  │  │   └── Ingress        │   │            │
│  │    └────────────────────────┘   │  │  └──────────────────────┘   │            │
│  │                                 │  │                             │            │
│  │    ┌────────────────────────┐   │  │  ┌──────────────────────┐   │            │
│  │    │   中间件集群           │   │  │  │   中间件集群         │   │            │
│  │    │   ├── MySQL (主)       │◀──┼──┼─▶│   ├── MySQL (从)     │   │            │
│  │    │   ├── Redis Cluster    │◀──┼──┼─▶│   ├── Redis Cluster  │   │            │
│  │    │   ├── RocketMQ         │◀──┼──┼─▶│   ├── RocketMQ       │   │            │
│  │    │   └── MinIO            │◀──┼──┼─▶│   └── MinIO          │   │            │
│  │    └────────────────────────┘   │  │  └──────────────────────┘   │            │
│  │               同步              │  │           同步              │            │
│  └─────────────────────────────────┘  └─────────────────────────────┘            │
│                                                                                     │
│                         ┌───────────────────────┐                                  │
│                         │   跨机房专线/VPN      │                                  │
│                         │   延迟 < 10ms         │                                  │
│                         └───────────────────────┘                                  │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、K8s 集群规划

### 2.1 节点规划

```yaml
# 机房 A - 生产集群
cluster-prod-a:
  masters: 3
  workers:
    # 业务节点
    - pool: business
      count: 20
      spec: 16C64G
      labels:
        node-type: business

    # 中间件节点
    - pool: middleware
      count: 10
      spec: 16C64G500G-SSD
      labels:
        node-type: middleware
      taints:
        - middleware=true:NoSchedule

    # 监控节点
    - pool: monitoring
      count: 6
      spec: 8C32G2T-SSD
      labels:
        node-type: monitoring
      taints:
        - monitoring=true:NoSchedule

    # 日志节点
    - pool: logging
      count: 6
      spec: 8C32G4T-HDD
      labels:
        node-type: logging
      taints:
        - logging=true:NoSchedule

# 机房 B - 同等配置
cluster-prod-b:
  # 同 cluster-prod-a
```

### 2.2 命名空间规划

```yaml
namespaces:
  # 系统组件
  - name: kube-system          # K8s 系统组件
  - name: ingress-system       # Ingress 控制器
  - name: cert-manager         # 证书管理

  # 中间件
  - name: middleware           # MySQL, Redis, MQ 等

  # 可观测性
  - name: monitoring           # Prometheus, Grafana
  - name: logging              # Loki, Promtail
  - name: tracing              # Tempo

  # 平台服务
  - name: platform             # 平台基础服务

  # 业务服务
  - name: business             # 业务服务

  # 任务调度
  - name: jobs                 # 定时任务

  # 开发测试
  - name: dev                  # 开发环境
  - name: test                 # 测试环境
  - name: staging              # 预发布环境
```

### 2.3 资源配额

```yaml
# 业务命名空间配额
apiVersion: v1
kind: ResourceQuota
metadata:
  name: business-quota
  namespace: business
spec:
  hard:
    requests.cpu: "200"
    requests.memory: 400Gi
    limits.cpu: "400"
    limits.memory: 800Gi
    pods: "500"
    services: "100"
    persistentvolumeclaims: "100"
```

## 三、网络架构

### 3.1 网络插件 - Cilium

```yaml
# cilium-values.yaml
cluster:
  name: prod-cluster-a
  id: 1

ipam:
  mode: kubernetes

kubeProxyReplacement: strict

hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true

# 跨集群网络
clustermesh:
  useAPIServer: true
  apiserver:
    replicas: 3
```

### 3.2 Ingress - APISIX

```yaml
# apisix-values.yaml
apisix:
  enabled: true

  replicaCount: 3

  resources:
    requests:
      cpu: 2
      memory: 4Gi
    limits:
      cpu: 4
      memory: 8Gi

gateway:
  type: LoadBalancer
  http:
    enabled: true
    containerPort: 9080
  https:
    enabled: true
    containerPort: 9443
  stream:
    enabled: true    # TCP/UDP 支持

dashboard:
  enabled: true

etcd:
  enabled: true
  replicaCount: 3
```

### 3.3 服务网格 - Istio（可选）

```yaml
# istio-values.yaml
global:
  meshID: mesh1
  multiCluster:
    clusterName: cluster-a
  network: network1

pilot:
  autoscaleMin: 2
  resources:
    requests:
      cpu: 500m
      memory: 2Gi

# 启用 mTLS
meshConfig:
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_CAPTURE: "true"
  enableAutoMtls: true
```

## 四、存储架构

### 4.1 存储类型

```yaml
# StorageClass 定义
---
# 高性能 SSD（数据库、缓存）
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: disk.csi.xxx.com
parameters:
  type: cloud_essd
  performanceLevel: PL1
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
# 普通 SSD（一般服务）
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-ssd
provisioner: disk.csi.xxx.com
parameters:
  type: cloud_ssd
reclaimPolicy: Delete
allowVolumeExpansion: true

---
# 大容量 HDD（日志、归档）
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: capacity-hdd
provisioner: disk.csi.xxx.com
parameters:
  type: cloud_efficiency
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### 4.2 对象存储 - MinIO

```yaml
# minio-values.yaml
mode: distributed

replicas: 4

persistence:
  enabled: true
  storageClass: capacity-hdd
  size: 10Ti

resources:
  requests:
    memory: 16Gi
    cpu: 4

# 双机房配置复制
environment:
  MINIO_SITE_REPLICATION_SITE_1: "http://minio-a:9000"
  MINIO_SITE_REPLICATION_SITE_2: "http://minio-b:9000"
```

## 五、镜像仓库 - Harbor

### 5.1 部署配置

```yaml
# harbor-values.yaml
expose:
  type: ingress
  ingress:
    hosts:
      core: harbor.example.com
    className: apisix

persistence:
  enabled: true
  persistentVolumeClaim:
    registry:
      storageClass: capacity-hdd
      size: 5Ti
    database:
      storageClass: fast-ssd
      size: 100Gi

# 双机房镜像复制
replication:
  - name: cluster-b
    endpoint: https://harbor-b.example.com
    triggerMode: EventBased
    filters:
      - type: name
        value: "**"
```

### 5.2 镜像仓库规范

```
harbor.example.com/
├── library/              # 公共基础镜像
│   ├── openjdk:21
│   ├── openjdk:17
│   ├── openjdk:11
│   ├── openjdk:8
│   ├── golang:1.21
│   ├── python:3.11
│   └── node:20
│
├── platform/             # 平台服务镜像
│   ├── gateway
│   ├── auth-service
│   ├── user-service
│   └── ...
│
├── business/             # 业务服务镜像
│   ├── order-service
│   ├── product-service
│   └── ...
│
├── middleware/           # 中间件镜像
│   ├── mysql
│   ├── redis
│   └── ...
│
└── tools/                # 工具镜像
    ├── arthas
    ├── debug
    └── ...
```

## 六、证书管理 - Cert-Manager

```yaml
# cert-manager 配置
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: apisix

---
# 内部 CA（内部服务 mTLS）
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: internal-ca
spec:
  ca:
    secretName: internal-ca-key-pair
```

## 七、GitOps - ArgoCD

### 7.1 ArgoCD 配置

```yaml
# argocd-values.yaml
server:
  replicas: 2

  ingress:
    enabled: true
    hosts:
      - argocd.example.com

controller:
  replicas: 2

repoServer:
  replicas: 2

applicationSet:
  enabled: true
  replicas: 2

# RBAC 配置
configs:
  rbac:
    policy.csv: |
      p, role:admin, applications, *, */*, allow
      p, role:developer, applications, get, */*, allow
      p, role:developer, applications, sync, */dev/*, allow
      g, admin-group, role:admin
      g, dev-group, role:developer
```

### 7.2 应用定义

```yaml
# Application 模板
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: business-services
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://gitlab.example.com/platform/deployments.git
        revision: HEAD
        directories:
          - path: business/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: business
      source:
        repoURL: https://gitlab.example.com/platform/deployments.git
        targetRevision: HEAD
        path: '{{path}}'
        helm:
          valueFiles:
            - values.yaml
            - values-prod.yaml
      destination:
        server: https://kubernetes.default.svc
        namespace: business
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## 八、基础设施即代码 - Terraform

```hcl
# main.tf
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  backend "s3" {
    bucket = "terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "cn-beijing"
  }
}

# K8s 集群（示例：阿里云 ACK）
module "kubernetes_cluster" {
  source = "./modules/kubernetes"

  cluster_name = "prod-cluster-a"
  region       = "cn-beijing"

  master_count = 3
  worker_pools = [
    {
      name          = "business"
      instance_type = "ecs.g7.4xlarge"
      min_size      = 10
      max_size      = 50
    },
    {
      name          = "middleware"
      instance_type = "ecs.g7.4xlarge"
      min_size      = 6
      max_size      = 20
      taints        = ["middleware=true:NoSchedule"]
    }
  ]
}

# 安装基础组件
module "cluster_addons" {
  source = "./modules/addons"

  cluster_id = module.kubernetes_cluster.id

  addons = {
    cilium       = true
    apisix       = true
    cert_manager = true
    argocd       = true
  }
}
```

## 九、资源清单

| 资源类型 | 机房 A | 机房 B | 总计 | 用途 |
|---------|--------|--------|------|------|
| K8s Master | 3 | 3 | 6 | 控制平面 |
| 业务节点 | 20 | 20 | 40 | 业务服务 |
| 中间件节点 | 10 | 10 | 20 | MySQL/Redis/MQ |
| 监控节点 | 6 | 6 | 12 | 监控存储 |
| 日志节点 | 6 | 6 | 12 | 日志存储 |
| **总节点数** | **45** | **45** | **90** | |
| SSD 存储 | 50TB | 50TB | 100TB | 数据库/缓存 |
| HDD 存储 | 200TB | 200TB | 400TB | 日志/对象存储 |
