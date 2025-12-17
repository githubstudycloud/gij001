# 03 - 中间件层设计

## 一、中间件架构总览

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              中间件层架构                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                            数据层                                            │   │
│  │                                                                             │   │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │   │
│  │   │   MySQL     │  │   Redis     │  │ Elasticsearch│  │   MinIO     │       │   │
│  │   │   Cluster   │  │   Cluster   │  │   Cluster   │  │   Cluster   │       │   │
│  │   │             │  │             │  │             │  │             │       │   │
│  │   │ ┌───┬───┐   │  │  6 Nodes    │  │  3+ Nodes   │  │  4 Nodes    │       │   │
│  │   │ │ M │ S │   │  │  3M + 3S    │  │             │  │             │       │   │
│  │   │ └───┴───┘   │  │             │  │             │  │             │       │   │
│  │   │ + ShardingSphere│             │  │             │  │             │       │   │
│  │   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │   │
│  │                                                                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                            消息层                                            │   │
│  │                                                                             │   │
│  │   ┌─────────────────────────────────────────────────────────────────────┐   │   │
│  │   │                         RocketMQ Cluster                             │   │   │
│  │   │                                                                     │   │   │
│  │   │   NameServer x 2    Broker-Master x 2    Broker-Slave x 2          │   │   │
│  │   │                                                                     │   │   │
│  │   │   支持: 普通消息 / 顺序消息 / 延迟消息 / 事务消息                    │   │   │
│  │   └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                                                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                          服务治理层                                          │   │
│  │                                                                             │   │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                        │   │
│  │   │   Nacos     │  │   Sentinel  │  │   Seata     │                        │   │
│  │   │   Cluster   │  │   Dashboard │  │   Server    │                        │   │
│  │   │             │  │             │  │             │                        │   │
│  │   │ 配置中心    │  │ 限流熔断    │  │ 分布式事务  │                        │   │
│  │   │ 注册中心    │  │ 流量控制    │  │ AT/TCC 模式 │                        │   │
│  │   └─────────────┘  └─────────────┘  └─────────────┘                        │   │
│  │                                                                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、MySQL 集群

### 2.1 架构设计

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MySQL 高可用架构                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                        ┌───────────────────┐                               │
│                        │   ShardingSphere  │                               │
│                        │      Proxy        │                               │
│                        │   (读写分离/分片)  │                               │
│                        └─────────┬─────────┘                               │
│                                  │                                         │
│          ┌───────────────────────┼───────────────────────┐                │
│          │                       │                       │                │
│          ▼                       ▼                       ▼                │
│  ┌───────────────┐      ┌───────────────┐      ┌───────────────┐         │
│  │   分片 0      │      │   分片 1      │      │   分片 N      │         │
│  │               │      │               │      │               │         │
│  │  ┌─────────┐  │      │  ┌─────────┐  │      │  ┌─────────┐  │         │
│  │  │ Master  │  │      │  │ Master  │  │      │  │ Master  │  │         │
│  │  └────┬────┘  │      │  └────┬────┘  │      │  └────┬────┘  │         │
│  │       │       │      │       │       │      │       │       │         │
│  │  ┌────┴────┐  │      │  ┌────┴────┐  │      │  ┌────┴────┐  │         │
│  │  │  Slave  │  │      │  │  Slave  │  │      │  │  Slave  │  │         │
│  │  └─────────┘  │      │  └─────────┘  │      │  └─────────┘  │         │
│  └───────────────┘      └───────────────┘      └───────────────┘         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 ShardingSphere 配置

```yaml
# shardingsphere-proxy config-sharding.yaml
schemaName: platform

dataSources:
  ds_0:
    url: jdbc:mysql://mysql-0:3306/platform?serverTimezone=UTC
    username: root
    password: ENC(xxx)
    connectionTimeoutMilliseconds: 30000
    idleTimeoutMilliseconds: 60000
    maxLifetimeMilliseconds: 1800000
    maxPoolSize: 50
    minPoolSize: 10
  ds_1:
    url: jdbc:mysql://mysql-1:3306/platform?serverTimezone=UTC
    # ... 同上

rules:
  # 分片规则
  - !SHARDING
    tables:
      # 订单表 - 按用户ID分片
      t_order:
        actualDataNodes: ds_${0..1}.t_order_${0..15}
        tableStrategy:
          standard:
            shardingColumn: user_id
            shardingAlgorithmName: order_table_hash
        keyGenerateStrategy:
          column: id
          keyGeneratorName: snowflake

      # 订单明细 - 绑定订单表
      t_order_item:
        actualDataNodes: ds_${0..1}.t_order_item_${0..15}
        tableStrategy:
          standard:
            shardingColumn: user_id
            shardingAlgorithmName: order_table_hash

    bindingTables:
      - t_order, t_order_item

    shardingAlgorithms:
      order_table_hash:
        type: HASH_MOD
        props:
          sharding-count: 16

    keyGenerators:
      snowflake:
        type: SNOWFLAKE

  # 读写分离
  - !READWRITE_SPLITTING
    dataSources:
      readwrite_ds_0:
        writeDataSourceName: ds_0
        readDataSourceNames:
          - ds_0_slave
        loadBalancerName: round_robin
    loadBalancers:
      round_robin:
        type: ROUND_ROBIN
```

### 2.3 数据库规范

```sql
-- 表设计规范
CREATE TABLE `t_order` (
  `id` bigint NOT NULL COMMENT '主键ID（雪花算法）',
  `order_no` varchar(32) NOT NULL COMMENT '订单号',
  `user_id` bigint NOT NULL COMMENT '用户ID（分片键）',
  `tenant_id` bigint NOT NULL COMMENT '租户ID',
  `status` tinyint NOT NULL DEFAULT '0' COMMENT '状态',
  `total_amount` decimal(12,2) NOT NULL COMMENT '总金额',
  `created_by` bigint DEFAULT NULL COMMENT '创建人',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_by` bigint DEFAULT NULL COMMENT '更新人',
  `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` tinyint NOT NULL DEFAULT '0' COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_tenant_id` (`tenant_id`),
  KEY `idx_order_no` (`order_no`),
  KEY `idx_created_time` (`created_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';
```

## 三、Redis 集群

### 3.1 集群配置

```yaml
# redis-cluster helm values
cluster:
  enabled: true
  nodes: 6        # 3 主 3 从
  replicas: 1

redis:
  resources:
    requests:
      cpu: 2
      memory: 8Gi
    limits:
      cpu: 4
      memory: 16Gi

  persistence:
    enabled: true
    storageClass: fast-ssd
    size: 100Gi

  extraFlags:
    - "--maxmemory 12gb"
    - "--maxmemory-policy allkeys-lru"
    - "--tcp-keepalive 300"
    - "--timeout 0"

# 哨兵模式（备选）
sentinel:
  enabled: false
```

### 3.2 缓存使用规范

```java
// 缓存 Key 规范
public class CacheKeys {
    // 格式: {业务}:{模块}:{标识}

    // 用户相关
    public static final String USER_INFO = "user:info:%s";           // user:info:{userId}
    public static final String USER_TOKEN = "user:token:%s";         // user:token:{token}
    public static final String USER_PERMISSION = "user:perm:%s";     // user:perm:{userId}

    // 租户相关
    public static final String TENANT_INFO = "tenant:info:%s";       // tenant:info:{tenantId}

    // 业务相关
    public static final String ORDER_INFO = "order:info:%s";         // order:info:{orderId}
    public static final String PRODUCT_STOCK = "product:stock:%s";   // product:stock:{productId}

    // 分布式锁
    public static final String LOCK_ORDER = "lock:order:%s";         // lock:order:{orderId}
}

// 过期时间规范
public class CacheTTL {
    public static final long USER_INFO = 30 * 60;        // 30 分钟
    public static final long USER_TOKEN = 7 * 24 * 60 * 60; // 7 天
    public static final long PRODUCT_INFO = 60 * 60;     // 1 小时
    public static final long HOT_DATA = 5 * 60;          // 5 分钟
}
```

### 3.3 多级缓存

```java
@Configuration
public class MultilevelCacheConfig {

    /**
     * 一级缓存：本地 Caffeine
     */
    @Bean
    public Cache<String, Object> localCache() {
        return Caffeine.newBuilder()
            .maximumSize(10_000)
            .expireAfterWrite(5, TimeUnit.MINUTES)
            .recordStats()
            .build();
    }

    /**
     * 二级缓存：Redis
     */
    @Bean
    public RedisTemplate<String, Object> redisTemplate(RedisConnectionFactory factory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(factory);
        template.setKeySerializer(new StringRedisSerializer());
        template.setValueSerializer(new GenericJackson2JsonRedisSerializer());
        return template;
    }
}

@Service
public class MultilevelCacheService {

    @Autowired
    private Cache<String, Object> localCache;

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    public <T> T get(String key, Class<T> type, Supplier<T> loader) {
        // 1. 查本地缓存
        T value = (T) localCache.getIfPresent(key);
        if (value != null) {
            return value;
        }

        // 2. 查 Redis
        value = (T) redisTemplate.opsForValue().get(key);
        if (value != null) {
            localCache.put(key, value);
            return value;
        }

        // 3. 查数据库
        value = loader.get();
        if (value != null) {
            redisTemplate.opsForValue().set(key, value, CacheTTL.DEFAULT, TimeUnit.SECONDS);
            localCache.put(key, value);
        }

        return value;
    }
}
```

## 四、RocketMQ 集群

### 4.1 集群配置

```yaml
# rocketmq helm values
nameserver:
  replicaCount: 2
  resources:
    requests:
      cpu: 1
      memory: 2Gi

broker:
  replicaCount: 2

  config:
    brokerClusterName: platform-cluster
    brokerRole: ASYNC_MASTER
    flushDiskType: ASYNC_FLUSH

    # 存储配置
    storePathRootDir: /data/rocketmq/store
    storePathCommitLog: /data/rocketmq/store/commitlog

    # 性能配置
    sendMessageThreadPoolNums: 16
    pullMessageThreadPoolNums: 32

    # 消息保留
    fileReservedTime: 72  # 72小时

  persistence:
    enabled: true
    storageClass: fast-ssd
    size: 500Gi

# Slave 配置
brokerSlave:
  enabled: true
  replicaCount: 2
  config:
    brokerRole: SLAVE
```

### 4.2 消息使用规范

```java
// Topic 命名规范: {环境}_{业务}_{模块}_{动作}
public class MQTopics {
    // 订单相关
    public static final String ORDER_CREATE = "PROD_ORDER_CREATE";
    public static final String ORDER_PAY = "PROD_ORDER_PAY";
    public static final String ORDER_CANCEL = "PROD_ORDER_CANCEL";

    // 库存相关
    public static final String STOCK_DEDUCT = "PROD_STOCK_DEDUCT";
    public static final String STOCK_ROLLBACK = "PROD_STOCK_ROLLBACK";

    // 通知相关
    public static final String NOTIFICATION_SMS = "PROD_NOTIFICATION_SMS";
    public static final String NOTIFICATION_EMAIL = "PROD_NOTIFICATION_EMAIL";
}

// Consumer Group 命名: GID_{服务名}_{Topic}
public class MQConsumerGroups {
    public static final String ORDER_SERVICE_ORDER_CREATE = "GID_ORDER_SERVICE_ORDER_CREATE";
    public static final String STOCK_SERVICE_STOCK_DEDUCT = "GID_STOCK_SERVICE_STOCK_DEDUCT";
}
```

### 4.3 事务消息示例

```java
@Service
public class OrderTransactionService {

    @Autowired
    private RocketMQTemplate rocketMQTemplate;

    @Autowired
    private OrderMapper orderMapper;

    /**
     * 创建订单 - 事务消息
     */
    public void createOrderWithTransaction(CreateOrderRequest request) {
        String txId = UUID.randomUUID().toString();

        // 发送事务消息
        rocketMQTemplate.sendMessageInTransaction(
            "order-tx-producer-group",
            MQTopics.ORDER_CREATE,
            MessageBuilder
                .withPayload(request)
                .setHeader("txId", txId)
                .build(),
            request  // arg 参数，传给本地事务
        );
    }

    /**
     * 本地事务监听器
     */
    @RocketMQTransactionListener(txProducerGroup = "order-tx-producer-group")
    public class OrderTransactionListener implements RocketMQLocalTransactionListener {

        @Override
        public RocketMQLocalTransactionState executeLocalTransaction(Message msg, Object arg) {
            CreateOrderRequest request = (CreateOrderRequest) arg;
            try {
                // 执行本地事务
                orderMapper.insert(convertToOrder(request));
                return RocketMQLocalTransactionState.COMMIT;
            } catch (Exception e) {
                log.error("本地事务执行失败", e);
                return RocketMQLocalTransactionState.ROLLBACK;
            }
        }

        @Override
        public RocketMQLocalTransactionState checkLocalTransaction(Message msg) {
            String txId = msg.getHeaders().get("txId", String.class);
            // 检查本地事务状态
            Order order = orderMapper.selectByTxId(txId);
            if (order != null) {
                return RocketMQLocalTransactionState.COMMIT;
            }
            return RocketMQLocalTransactionState.UNKNOWN;
        }
    }
}
```

## 五、Nacos 配置中心

### 5.1 集群配置

```yaml
# nacos helm values
nacos:
  replicaCount: 3

  mode: cluster

  storage:
    type: mysql
    db:
      host: mysql-nacos
      name: nacos
      port: 3306
      username: nacos
      password: ENC(xxx)

  resources:
    requests:
      cpu: 2
      memory: 4Gi

persistence:
  enabled: true
  storageClass: fast-ssd
  size: 50Gi
```

### 5.2 配置管理规范

```
Nacos 配置命名空间:
├── dev           # 开发环境
├── test          # 测试环境
├── staging       # 预发布环境
└── prod          # 生产环境

配置 Data ID 规范:
├── {service-name}.yaml              # 服务主配置
├── {service-name}-{profile}.yaml    # 环境特定配置
└── common.yaml                       # 公共配置

配置 Group 规范:
├── DEFAULT_GROUP      # 默认组
├── PLATFORM_GROUP     # 平台服务组
├── BUSINESS_GROUP     # 业务服务组
└── MIDDLEWARE_GROUP   # 中间件配置组
```

### 5.3 配置示例

```yaml
# common.yaml (公共配置)
spring:
  jackson:
    date-format: yyyy-MM-dd HH:mm:ss
    time-zone: GMT+8

  servlet:
    multipart:
      max-file-size: 100MB
      max-request-size: 100MB

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus

logging:
  level:
    root: INFO

# 全局超时配置
feign:
  client:
    config:
      default:
        connectTimeout: 5000
        readTimeout: 10000

---
# order-service.yaml (服务配置)
server:
  port: 8080

order:
  timeout:
    pay: 30           # 支付超时（分钟）
    confirm: 7        # 确认收货超时（天）

  stock:
    deduct-strategy: optimistic  # 库存扣减策略
```

## 六、Elasticsearch 集群

### 6.1 集群配置

```yaml
# elasticsearch helm values
replicas: 3

esConfig:
  elasticsearch.yml: |
    cluster.name: "platform-es"
    network.host: 0.0.0.0

    # 跨域
    http.cors.enabled: true
    http.cors.allow-origin: "*"

    # 慢查询日志
    index.search.slowlog.threshold.query.warn: 10s
    index.search.slowlog.threshold.fetch.warn: 1s

resources:
  requests:
    cpu: 4
    memory: 16Gi
  limits:
    cpu: 8
    memory: 32Gi

volumeClaimTemplate:
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 500Gi

# ILM 生命周期策略
esLifecyclePolicy:
  phases:
    hot:
      min_age: 0ms
      actions:
        rollover:
          max_size: 50gb
          max_age: 7d
    warm:
      min_age: 7d
      actions:
        shrink:
          number_of_shards: 1
    cold:
      min_age: 30d
      actions:
        freeze: {}
    delete:
      min_age: 365d
      actions:
        delete: {}
```

## 七、中间件资源清单

| 组件 | 节点数 | 规格 | 存储 | 备注 |
|------|--------|------|------|------|
| MySQL | 4 (2主2从) | 16C64G | 2TB SSD | + ShardingSphere |
| Redis | 6 (3主3从) | 8C32G | 100GB SSD | Cluster 模式 |
| RocketMQ | 6 (2NS+2M+2S) | 8C16G | 500GB SSD | 双主双从 |
| Nacos | 3 | 4C8G | 50GB SSD | 集群模式 |
| Elasticsearch | 3 | 16C32G | 500GB SSD | 按需扩展 |
| MinIO | 4 | 8C16G | 10TB HDD | 分布式 |
