# 14 - 中间件部署清单

## 一、部署总览

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              测试环境中间件部署                                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  5台服务器 (每台 16C32G) 部署规划                                                   │
│                                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐│
│  │  Server-1   │  │  Server-2   │  │  Server-3   │  │  Server-4   │  │  Server-5  ││
│  │  K8s Master │  │  Worker-1   │  │  Worker-2   │  │  Worker-3   │  │  Worker-4  ││
│  │             │  │  中间件     │  │  中间件     │  │  可观测性   │  │  业务服务  ││
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘│
│                                                                                     │
│  中间件清单:                                                                        │
│  ├── ✅ 复用: MySQL, Redis, GitLab, S3, Kafka(外部), RocketMQ(外部)               │
│  ├── ⭐ 新增: Nacos, RocketMQ(内部), Elasticsearch, MinIO                          │
│  └── 📊 可观测: VictoriaMetrics, Loki, Tempo, Grafana, OTel Collector             │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、服务器详细分配

### 2.1 Server-1 (K8s Master)

| 组件 | 配置 | 端口 | 说明 |
|------|------|------|------|
| K8s Control Plane | - | 6443 | API Server |
| etcd | 2C4G | 2379,2380 | 状态存储 |
| Nacos Node-1 | 2C4G | 8848 | 配置/注册中心 |
| Grafana | 2C4G | 3000 | 可视化面板 |
| **资源占用** | **8C16G** | - | - |

### 2.2 Server-2 (Worker - 中间件)

| 组件 | 配置 | 端口 | 说明 |
|------|------|------|------|
| Nacos Node-2 | 2C4G | 8848 | 配置/注册中心 |
| RocketMQ NameServer-1 | 1C2G | 9876 | 命名服务 |
| RocketMQ Broker-Master | 4C8G | 10911 | 主节点 |
| **资源占用** | **7C14G** | - | - |

### 2.3 Server-3 (Worker - 中间件)

| 组件 | 配置 | 端口 | 说明 |
|------|------|------|------|
| Nacos Node-3 | 2C4G | 8848 | 配置/注册中心 |
| RocketMQ NameServer-2 | 1C2G | 9876 | 命名服务 |
| RocketMQ Broker-Slave | 4C8G | 10911 | 从节点 |
| Elasticsearch Node-1 | 4C16G | 9200 | 搜索/日志 |
| **资源占用** | **11C30G** | - | - |

### 2.4 Server-4 (Worker - 可观测性)

| 组件 | 配置 | 端口 | 说明 |
|------|------|------|------|
| VictoriaMetrics | 4C8G | 8480,8481 | 指标存储 |
| Loki | 4C8G | 3100 | 日志存储 |
| Tempo | 2C4G | 3200 | 链路存储 |
| Elasticsearch Node-2 | 4C12G | 9200 | 搜索/日志 |
| **资源占用** | **14C32G** | - | - |

### 2.5 Server-5 (Worker - 业务)

| 组件 | 配置 | 端口 | 说明 |
|------|------|------|------|
| XXL-JOB Admin | 2C4G | 8080 | 任务调度 |
| MinIO | 2C4G | 9000 | 对象存储 |
| Elasticsearch Node-3 | 4C12G | 9200 | 搜索/日志 |
| 业务服务预留 | 8C12G | - | 微服务部署 |
| **资源占用** | **16C32G** | - | - |

## 三、部署脚本

### 3.1 K8s 集群初始化

```bash
#!/bin/bash
# k8s-init.sh - 在所有节点执行

# 禁用 swap
swapoff -a
sed -i '/swap/d' /etc/fstab

# 加载内核模块
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# 内核参数
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# 安装 containerd
yum install -y containerd.io
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable --now containerd

# 安装 kubeadm
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
EOF

yum install -y kubelet kubeadm kubectl
systemctl enable kubelet
```

### 3.2 Master 节点初始化

```bash
#!/bin/bash
# k8s-master-init.sh - 在 Master 节点执行

# 初始化集群
kubeadm init \
  --apiserver-advertise-address=192.168.1.101 \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --image-repository=registry.aliyuncs.com/google_containers

# 配置 kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 安装 Calico 网络
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# 生成 Worker 加入命令
kubeadm token create --print-join-command > /tmp/join-command.sh
```

### 3.3 Nacos 集群部署

```yaml
# nacos-deployment.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nacos-config
  namespace: middleware
data:
  NACOS_SERVERS: "nacos-0.nacos-headless:8848 nacos-1.nacos-headless:8848 nacos-2.nacos-headless:8848"
  MYSQL_SERVICE_HOST: "mysql.company.com"
  MYSQL_SERVICE_PORT: "3306"
  MYSQL_SERVICE_DB_NAME: "nacos_config"
  MYSQL_SERVICE_USER: "nacos"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nacos
  namespace: middleware
spec:
  serviceName: nacos-headless
  replicas: 3
  selector:
    matchLabels:
      app: nacos
  template:
    metadata:
      labels:
        app: nacos
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: nacos
              topologyKey: kubernetes.io/hostname
      containers:
        - name: nacos
          image: nacos/nacos-server:v2.3.0
          ports:
            - containerPort: 8848
              name: client
            - containerPort: 9848
              name: client-rpc
            - containerPort: 9849
              name: raft-rpc
          resources:
            requests:
              cpu: "500m"
              memory: "2Gi"
            limits:
              cpu: "2000m"
              memory: "4Gi"
          env:
            - name: MODE
              value: "cluster"
            - name: NACOS_SERVER_PORT
              value: "8848"
            - name: SPRING_DATASOURCE_PLATFORM
              value: "mysql"
            - name: MYSQL_SERVICE_HOST
              valueFrom:
                configMapKeyRef:
                  name: nacos-config
                  key: MYSQL_SERVICE_HOST
            - name: MYSQL_SERVICE_PORT
              valueFrom:
                configMapKeyRef:
                  name: nacos-config
                  key: MYSQL_SERVICE_PORT
            - name: MYSQL_SERVICE_DB_NAME
              valueFrom:
                configMapKeyRef:
                  name: nacos-config
                  key: MYSQL_SERVICE_DB_NAME
            - name: MYSQL_SERVICE_USER
              valueFrom:
                configMapKeyRef:
                  name: nacos-config
                  key: MYSQL_SERVICE_USER
            - name: MYSQL_SERVICE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: nacos-secret
                  key: mysql-password
            - name: NACOS_SERVERS
              valueFrom:
                configMapKeyRef:
                  name: nacos-config
                  key: NACOS_SERVERS
          livenessProbe:
            httpGet:
              path: /nacos/v1/console/health/readiness
              port: 8848
            initialDelaySeconds: 60
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /nacos/v1/console/health/readiness
              port: 8848
            initialDelaySeconds: 30
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: nacos-headless
  namespace: middleware
spec:
  clusterIP: None
  ports:
    - port: 8848
      name: server
    - port: 9848
      name: client-rpc
    - port: 9849
      name: raft-rpc
  selector:
    app: nacos
---
apiVersion: v1
kind: Service
metadata:
  name: nacos
  namespace: middleware
spec:
  type: NodePort
  ports:
    - port: 8848
      targetPort: 8848
      nodePort: 30848
  selector:
    app: nacos
```

### 3.4 RocketMQ 集群部署

```yaml
# rocketmq-deployment.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rocketmq-broker-config
  namespace: middleware
data:
  broker-master.conf: |
    brokerClusterName=DefaultCluster
    brokerName=broker-a
    brokerId=0
    deleteWhen=04
    fileReservedTime=48
    brokerRole=SYNC_MASTER
    flushDiskType=ASYNC_FLUSH
    namesrvAddr=rocketmq-namesrv-0.rocketmq-namesrv:9876;rocketmq-namesrv-1.rocketmq-namesrv:9876
    autoCreateTopicEnable=true
    autoCreateSubscriptionGroup=true
  broker-slave.conf: |
    brokerClusterName=DefaultCluster
    brokerName=broker-a
    brokerId=1
    deleteWhen=04
    fileReservedTime=48
    brokerRole=SLAVE
    flushDiskType=ASYNC_FLUSH
    namesrvAddr=rocketmq-namesrv-0.rocketmq-namesrv:9876;rocketmq-namesrv-1.rocketmq-namesrv:9876
---
# NameServer StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rocketmq-namesrv
  namespace: middleware
spec:
  serviceName: rocketmq-namesrv
  replicas: 2
  selector:
    matchLabels:
      app: rocketmq-namesrv
  template:
    metadata:
      labels:
        app: rocketmq-namesrv
    spec:
      containers:
        - name: namesrv
          image: apache/rocketmq:5.1.4
          command: ["sh", "mqnamesrv"]
          ports:
            - containerPort: 9876
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "1000m"
              memory: "2Gi"
          readinessProbe:
            tcpSocket:
              port: 9876
            initialDelaySeconds: 10
            periodSeconds: 5
---
# Broker Master
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rocketmq-broker-master
  namespace: middleware
spec:
  serviceName: rocketmq-broker-master
  replicas: 1
  selector:
    matchLabels:
      app: rocketmq-broker-master
  template:
    metadata:
      labels:
        app: rocketmq-broker-master
    spec:
      containers:
        - name: broker
          image: apache/rocketmq:5.1.4
          command: ["sh", "mqbroker", "-c", "/opt/rocketmq/conf/broker.conf"]
          ports:
            - containerPort: 10911
            - containerPort: 10909
          resources:
            requests:
              cpu: "2000m"
              memory: "4Gi"
            limits:
              cpu: "4000m"
              memory: "8Gi"
          volumeMounts:
            - name: broker-config
              mountPath: /opt/rocketmq/conf/broker.conf
              subPath: broker-master.conf
            - name: broker-data
              mountPath: /home/rocketmq/store
      volumes:
        - name: broker-config
          configMap:
            name: rocketmq-broker-config
  volumeClaimTemplates:
    - metadata:
        name: broker-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Gi
---
# Broker Slave
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rocketmq-broker-slave
  namespace: middleware
spec:
  serviceName: rocketmq-broker-slave
  replicas: 1
  selector:
    matchLabels:
      app: rocketmq-broker-slave
  template:
    metadata:
      labels:
        app: rocketmq-broker-slave
    spec:
      containers:
        - name: broker
          image: apache/rocketmq:5.1.4
          command: ["sh", "mqbroker", "-c", "/opt/rocketmq/conf/broker.conf"]
          ports:
            - containerPort: 10911
            - containerPort: 10909
          resources:
            requests:
              cpu: "2000m"
              memory: "4Gi"
            limits:
              cpu: "4000m"
              memory: "8Gi"
          volumeMounts:
            - name: broker-config
              mountPath: /opt/rocketmq/conf/broker.conf
              subPath: broker-slave.conf
            - name: broker-data
              mountPath: /home/rocketmq/store
      volumes:
        - name: broker-config
          configMap:
            name: rocketmq-broker-config
  volumeClaimTemplates:
    - metadata:
        name: broker-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Gi
```

### 3.5 Elasticsearch 集群部署

```yaml
# elasticsearch-deployment.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: middleware
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      initContainers:
        - name: init-sysctl
          image: busybox
          command: ["sysctl", "-w", "vm.max_map_count=262144"]
          securityContext:
            privileged: true
      containers:
        - name: elasticsearch
          image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
          ports:
            - containerPort: 9200
              name: http
            - containerPort: 9300
              name: transport
          resources:
            requests:
              cpu: "2000m"
              memory: "8Gi"
            limits:
              cpu: "4000m"
              memory: "16Gi"
          env:
            - name: node.name
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: cluster.name
              value: "platform-es"
            - name: discovery.seed_hosts
              value: "elasticsearch-0.elasticsearch,elasticsearch-1.elasticsearch,elasticsearch-2.elasticsearch"
            - name: cluster.initial_master_nodes
              value: "elasticsearch-0,elasticsearch-1,elasticsearch-2"
            - name: ES_JAVA_OPTS
              value: "-Xms4g -Xmx4g"
            - name: xpack.security.enabled
              value: "false"
          volumeMounts:
            - name: data
              mountPath: /usr/share/elasticsearch/data
          readinessProbe:
            httpGet:
              path: /_cluster/health
              port: 9200
            initialDelaySeconds: 30
            periodSeconds: 10
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 100Gi
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: middleware
spec:
  clusterIP: None
  ports:
    - port: 9200
      name: http
    - port: 9300
      name: transport
  selector:
    app: elasticsearch
```

### 3.6 可观测性组件部署

```yaml
# observability-deployment.yaml

# VictoriaMetrics
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: victoriametrics
  namespace: monitoring
spec:
  serviceName: victoriametrics
  replicas: 1
  selector:
    matchLabels:
      app: victoriametrics
  template:
    metadata:
      labels:
        app: victoriametrics
    spec:
      containers:
        - name: victoriametrics
          image: victoriametrics/victoria-metrics:v1.96.0
          args:
            - "-storageDataPath=/data"
            - "-retentionPeriod=365d"
            - "-httpListenAddr=:8428"
          ports:
            - containerPort: 8428
          resources:
            requests:
              cpu: "2000m"
              memory: "4Gi"
            limits:
              cpu: "4000m"
              memory: "8Gi"
          volumeMounts:
            - name: data
              mountPath: /data
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 100Gi

# Loki
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: loki
  namespace: monitoring
spec:
  serviceName: loki
  replicas: 1
  selector:
    matchLabels:
      app: loki
  template:
    metadata:
      labels:
        app: loki
    spec:
      containers:
        - name: loki
          image: grafana/loki:2.9.3
          args:
            - "-config.file=/etc/loki/loki.yaml"
          ports:
            - containerPort: 3100
          resources:
            requests:
              cpu: "2000m"
              memory: "4Gi"
            limits:
              cpu: "4000m"
              memory: "8Gi"
          volumeMounts:
            - name: config
              mountPath: /etc/loki
            - name: data
              mountPath: /loki
      volumes:
        - name: config
          configMap:
            name: loki-config
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 200Gi

# Tempo
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: tempo
  namespace: monitoring
spec:
  serviceName: tempo
  replicas: 1
  selector:
    matchLabels:
      app: tempo
  template:
    metadata:
      labels:
        app: tempo
    spec:
      containers:
        - name: tempo
          image: grafana/tempo:2.3.1
          args:
            - "-config.file=/etc/tempo/tempo.yaml"
          ports:
            - containerPort: 3200
            - containerPort: 4317
            - containerPort: 4318
          resources:
            requests:
              cpu: "1000m"
              memory: "2Gi"
            limits:
              cpu: "2000m"
              memory: "4Gi"
          volumeMounts:
            - name: config
              mountPath: /etc/tempo
            - name: data
              mountPath: /var/tempo
      volumes:
        - name: config
          configMap:
            name: tempo-config
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 100Gi

# Grafana
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
        - name: grafana
          image: grafana/grafana:10.2.3
          ports:
            - containerPort: 3000
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "2000m"
              memory: "4Gi"
          env:
            - name: GF_SECURITY_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: grafana-secret
                  key: admin-password
          volumeMounts:
            - name: datasources
              mountPath: /etc/grafana/provisioning/datasources
            - name: data
              mountPath: /var/lib/grafana
      volumes:
        - name: datasources
          configMap:
            name: grafana-datasources
        - name: data
          persistentVolumeClaim:
            claimName: grafana-data

# OTel Collector DaemonSet
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-collector
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
        - name: collector
          image: otel/opentelemetry-collector-contrib:0.91.0
          args:
            - "--config=/etc/otel/config.yaml"
          ports:
            - containerPort: 4317
            - containerPort: 4318
            - containerPort: 8888
          resources:
            requests:
              cpu: "200m"
              memory: "400Mi"
            limits:
              cpu: "1000m"
              memory: "2Gi"
          volumeMounts:
            - name: config
              mountPath: /etc/otel
      volumes:
        - name: config
          configMap:
            name: otel-collector-config
```

### 3.7 XXL-JOB 部署

```yaml
# xxl-job-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: xxl-job-admin
  namespace: platform
spec:
  replicas: 2
  selector:
    matchLabels:
      app: xxl-job-admin
  template:
    metadata:
      labels:
        app: xxl-job-admin
    spec:
      containers:
        - name: xxl-job-admin
          image: xuxueli/xxl-job-admin:2.4.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "500m"
              memory: "1Gi"
            limits:
              cpu: "2000m"
              memory: "4Gi"
          env:
            - name: PARAMS
              value: >-
                --spring.datasource.url=jdbc:mysql://mysql:3306/xxl_job?useUnicode=true&characterEncoding=UTF-8&autoReconnect=true&serverTimezone=Asia/Shanghai
                --spring.datasource.username=xxl_job
                --spring.datasource.password=${MYSQL_PASSWORD}
                --xxl.job.accessToken=platform-xxl-job-token
          readinessProbe:
            httpGet:
              path: /xxl-job-admin
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: xxl-job-admin
  namespace: platform
spec:
  type: NodePort
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30880
  selector:
    app: xxl-job-admin
```

## 四、部署检查清单

### 4.1 部署前检查

| 检查项 | 说明 | 状态 |
|--------|------|------|
| 服务器网络互通 | 5台服务器网络互通 | □ |
| DNS 解析正常 | 内部 DNS 解析正常 | □ |
| 存储空间充足 | 每台服务器 >= 500GB | □ |
| 端口未占用 | 必要端口未被占用 | □ |
| 时间同步 | NTP 时间同步 | □ |
| 防火墙配置 | 必要端口已开放 | □ |

### 4.2 部署后验证

```bash
#!/bin/bash
# verify-deployment.sh

echo "=== K8s 集群状态 ==="
kubectl get nodes
kubectl get pods -A

echo "=== Nacos 集群状态 ==="
curl -s http://nacos:8848/nacos/v1/console/health/readiness

echo "=== RocketMQ 集群状态 ==="
kubectl exec -it rocketmq-broker-master-0 -- mqadmin clusterList -n rocketmq-namesrv:9876

echo "=== Elasticsearch 集群状态 ==="
curl -s http://elasticsearch:9200/_cluster/health?pretty

echo "=== 可观测性组件状态 ==="
curl -s http://victoriametrics:8428/-/healthy
curl -s http://loki:3100/ready
curl -s http://tempo:3200/ready
curl -s http://grafana:3000/api/health

echo "=== XXL-JOB 状态 ==="
curl -s http://xxl-job-admin:8080/xxl-job-admin
```

## 五、端口规划

### 5.1 内部端口

| 服务 | 端口 | 协议 | 用途 |
|------|------|------|------|
| Nacos | 8848 | HTTP | 配置/注册 |
| Nacos | 9848 | gRPC | 客户端通信 |
| RocketMQ NameServer | 9876 | TCP | 命名服务 |
| RocketMQ Broker | 10911 | TCP | 消息服务 |
| Elasticsearch | 9200 | HTTP | REST API |
| Elasticsearch | 9300 | TCP | 节点通信 |
| VictoriaMetrics | 8428 | HTTP | 指标写入/查询 |
| Loki | 3100 | HTTP | 日志服务 |
| Tempo | 3200 | HTTP | 链路服务 |
| Tempo | 4317 | gRPC | OTLP 接收 |
| Grafana | 3000 | HTTP | 可视化 |
| XXL-JOB | 8080 | HTTP | 任务调度 |
| OTel Collector | 4317 | gRPC | OTLP 接收 |
| OTel Collector | 4318 | HTTP | OTLP 接收 |

### 5.2 NodePort 端口

| 服务 | NodePort | 用途 |
|------|----------|------|
| Nacos | 30848 | 外部访问 |
| Grafana | 30300 | 监控面板 |
| XXL-JOB | 30880 | 任务管理 |
| RocketMQ Console | 30876 | MQ 管理 |

## 六、资源汇总

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              资源使用汇总                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  中间件资源:                                                                        │
│  ├── Nacos (3节点):        6C 12G                                                  │
│  ├── RocketMQ:             10C 20G (2NS + 1M + 1S)                                 │
│  ├── Elasticsearch:        12C 48G (3节点)                                         │
│  └── 小计:                 28C 80G                                                  │
│                                                                                     │
│  可观测性资源:                                                                      │
│  ├── VictoriaMetrics:      4C 8G                                                   │
│  ├── Loki:                 4C 8G                                                   │
│  ├── Tempo:                2C 4G                                                   │
│  ├── Grafana:              2C 4G                                                   │
│  ├── OTel Collector:       5C 10G (DaemonSet x5)                                  │
│  └── 小计:                 17C 34G                                                  │
│                                                                                     │
│  任务调度:                                                                          │
│  └── XXL-JOB:              4C 8G (2副本)                                           │
│                                                                                     │
│  K8s 系统:                                                                          │
│  └── 控制面/etcd:          4C 8G                                                   │
│                                                                                     │
│  ─────────────────────────────────────────────────────────────────────────────────  │
│  总计: 53C 130G                                                                     │
│  可用: 80C 160G (5台 x 16C32G)                                                     │
│  剩余: 27C 30G (用于业务服务)                                                       │
│                                                                                     │
│  存储:                                                                              │
│  ├── Elasticsearch:        300GB                                                   │
│  ├── VictoriaMetrics:      100GB                                                   │
│  ├── Loki:                 200GB                                                   │
│  ├── Tempo:                100GB                                                   │
│  ├── RocketMQ:             100GB                                                   │
│  └── 总计:                 800GB                                                    │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```
