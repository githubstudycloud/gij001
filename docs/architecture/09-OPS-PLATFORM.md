# 09 - 运维平台设计

## 一、运维平台架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              运维平台架构                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           运维门户 (Vue3 + TypeScript)                       │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐              │   │
│  │  │发布中心 │ │服务管理 │ │资源管理 │ │配置中心 │ │调试工具 │              │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘              │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           运维服务层 (Java + Go)                             │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │   │
│  │  │ deploy-svc  │  │ service-svc │  │ config-svc  │  │ debug-svc   │        │   │
│  │  │ 发布服务    │  │ 服务管理    │  │ 配置管理    │  │ 调试服务    │        │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           基础设施层                                         │   │
│  │  K8s API │ ArgoCD API │ GitLab API │ Nacos API │ 监控 API                  │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、发布中心

### 2.1 发布流程

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              发布流程                                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐          │
│  │ 创建发布│───▶│ 环境选择│───▶│ 发布策略│───▶│ 审批流程│───▶│ 执行发布│          │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘          │
│                                                   │                │               │
│                                                   │                ▼               │
│                                              ┌────┴────┐    ┌─────────┐           │
│                                              │  回滚   │◀───│ 发布监控│           │
│                                              └─────────┘    └─────────┘           │
│                                                                                     │
│  发布策略:                                                                          │
│  ├── 滚动发布 (Rolling Update)     - 默认策略，逐步替换                            │
│  ├── 蓝绿发布 (Blue-Green)         - 全量切换，快速回滚                            │
│  ├── 金丝雀发布 (Canary)           - 小流量验证，逐步放量                          │
│  └── 灰度发布 (Gray Release)       - 按规则分流                                    │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 发布数据模型

```sql
-- 发布单表
CREATE TABLE deploy_release (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    release_no VARCHAR(50) NOT NULL COMMENT '发布单号',
    title VARCHAR(200) NOT NULL COMMENT '发布标题',
    description TEXT COMMENT '发布描述',
    service_id BIGINT NOT NULL COMMENT '服务ID',
    service_name VARCHAR(100) NOT NULL COMMENT '服务名称',
    env_id BIGINT NOT NULL COMMENT '环境ID',
    env_name VARCHAR(50) NOT NULL COMMENT '环境名称',
    deploy_type VARCHAR(20) NOT NULL COMMENT '发布类型: rolling/blue_green/canary/gray',
    image_tag VARCHAR(100) NOT NULL COMMENT '镜像版本',
    previous_tag VARCHAR(100) COMMENT '上一版本',
    status VARCHAR(20) NOT NULL COMMENT '状态: pending/approving/deploying/success/failed/rollback',
    progress INT DEFAULT 0 COMMENT '发布进度',
    create_by BIGINT NOT NULL COMMENT '创建人',
    approve_by BIGINT COMMENT '审批人',
    approve_time DATETIME COMMENT '审批时间',
    deploy_time DATETIME COMMENT '发布时间',
    finish_time DATETIME COMMENT '完成时间',
    rollback_time DATETIME COMMENT '回滚时间',
    error_msg TEXT COMMENT '错误信息',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_service (service_id),
    KEY idx_env (env_id),
    KEY idx_status (status),
    KEY idx_create_time (create_time)
) COMMENT '发布单表';

-- 发布详情表
CREATE TABLE deploy_release_detail (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    release_id BIGINT NOT NULL COMMENT '发布单ID',
    step_name VARCHAR(100) NOT NULL COMMENT '步骤名称',
    step_order INT NOT NULL COMMENT '步骤顺序',
    status VARCHAR(20) NOT NULL COMMENT '状态: pending/running/success/failed/skipped',
    start_time DATETIME COMMENT '开始时间',
    end_time DATETIME COMMENT '结束时间',
    duration INT COMMENT '耗时(秒)',
    log TEXT COMMENT '执行日志',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_release (release_id)
) COMMENT '发布详情表';

-- 灰度规则表
CREATE TABLE deploy_gray_rule (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    release_id BIGINT NOT NULL COMMENT '发布单ID',
    rule_type VARCHAR(20) NOT NULL COMMENT '规则类型: header/cookie/query/weight',
    rule_key VARCHAR(100) COMMENT '规则键',
    rule_value VARCHAR(500) COMMENT '规则值',
    weight INT COMMENT '权重(百分比)',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_release (release_id)
) COMMENT '灰度规则表';
```

### 2.3 发布服务

```java
// 发布服务
@Service
public class DeployService {

    @Autowired
    private ReleaseMapper releaseMapper;

    @Autowired
    private ArgocdClient argocdClient;

    @Autowired
    private KubernetesClient k8sClient;

    @Autowired
    private NotificationService notificationService;

    /**
     * 创建发布单
     */
    @Transactional
    public Long createRelease(ReleaseCreateDTO dto) {
        // 1. 检查是否有进行中的发布
        Release existing = releaseMapper.selectInProgress(dto.getServiceId(), dto.getEnvId());
        if (existing != null) {
            throw new BizException("该服务在此环境有进行中的发布");
        }

        // 2. 创建发布单
        Release release = Release.builder()
            .releaseNo(generateReleaseNo())
            .title(dto.getTitle())
            .description(dto.getDescription())
            .serviceId(dto.getServiceId())
            .serviceName(dto.getServiceName())
            .envId(dto.getEnvId())
            .envName(dto.getEnvName())
            .deployType(dto.getDeployType())
            .imageTag(dto.getImageTag())
            .status(ReleaseStatus.PENDING)
            .createBy(UserContext.getUserId())
            .build();
        releaseMapper.insert(release);

        // 3. 创建发布步骤
        createReleaseSteps(release);

        // 4. 保存灰度规则
        if (dto.getGrayRules() != null) {
            saveGrayRules(release.getId(), dto.getGrayRules());
        }

        return release.getId();
    }

    /**
     * 执行发布
     */
    @Async
    public void executeRelease(Long releaseId) {
        Release release = releaseMapper.selectById(releaseId);
        release.setStatus(ReleaseStatus.DEPLOYING);
        release.setDeployTime(LocalDateTime.now());
        releaseMapper.updateById(release);

        try {
            switch (release.getDeployType()) {
                case "rolling":
                    executeRollingDeploy(release);
                    break;
                case "blue_green":
                    executeBlueGreenDeploy(release);
                    break;
                case "canary":
                    executeCanaryDeploy(release);
                    break;
                case "gray":
                    executeGrayDeploy(release);
                    break;
            }

            // 发布成功
            release.setStatus(ReleaseStatus.SUCCESS);
            release.setFinishTime(LocalDateTime.now());
            release.setProgress(100);
            releaseMapper.updateById(release);

            // 发送通知
            notificationService.send(NotificationDTO.builder()
                .title("发布成功")
                .content(String.format("%s 发布到 %s 成功", release.getServiceName(), release.getEnvName()))
                .channels(List.of("feishu"))
                .build());

        } catch (Exception e) {
            // 发布失败
            release.setStatus(ReleaseStatus.FAILED);
            release.setFinishTime(LocalDateTime.now());
            release.setErrorMsg(e.getMessage());
            releaseMapper.updateById(release);

            // 发送告警
            notificationService.send(NotificationDTO.builder()
                .title("发布失败")
                .content(String.format("%s 发布到 %s 失败: %s",
                    release.getServiceName(), release.getEnvName(), e.getMessage()))
                .channels(List.of("feishu", "sms"))
                .level("critical")
                .build());
        }
    }

    /**
     * 滚动发布
     */
    private void executeRollingDeploy(Release release) {
        // 更新 K8s Deployment
        k8sClient.apps().deployments()
            .inNamespace(release.getEnvName())
            .withName(release.getServiceName())
            .edit(d -> {
                d.getSpec().getTemplate().getSpec().getContainers().get(0)
                    .setImage(getFullImageName(release));
                return d;
            });

        // 等待发布完成
        waitForRollout(release);
    }

    /**
     * 金丝雀发布
     */
    private void executeCanaryDeploy(Release release) {
        // 1. 创建 Canary Deployment
        Deployment canary = createCanaryDeployment(release);
        k8sClient.apps().deployments().create(canary);

        // 2. 配置流量规则 (Istio VirtualService)
        updateTrafficRules(release, 10); // 初始 10% 流量

        // 3. 监控并逐步放量
        int[] weights = {10, 30, 50, 80, 100};
        for (int weight : weights) {
            updateTrafficRules(release, weight);
            updateProgress(release, weight);

            // 等待验证
            Thread.sleep(60000); // 等待 1 分钟

            // 检查指标
            if (!checkCanaryMetrics(release)) {
                throw new BizException("金丝雀验证失败，指标异常");
            }
        }

        // 4. 完成金丝雀，删除旧版本
        deleteOldDeployment(release);
    }

    /**
     * 回滚
     */
    @Transactional
    public void rollback(Long releaseId) {
        Release release = releaseMapper.selectById(releaseId);
        if (release.getPreviousTag() == null) {
            throw new BizException("没有可回滚的版本");
        }

        // 回滚到上一版本
        k8sClient.apps().deployments()
            .inNamespace(release.getEnvName())
            .withName(release.getServiceName())
            .edit(d -> {
                d.getSpec().getTemplate().getSpec().getContainers().get(0)
                    .setImage(getFullImageName(release.getServiceName(), release.getPreviousTag()));
                return d;
            });

        // 更新状态
        release.setStatus(ReleaseStatus.ROLLBACK);
        release.setRollbackTime(LocalDateTime.now());
        releaseMapper.updateById(release);

        // 发送通知
        notificationService.send(NotificationDTO.builder()
            .title("发布已回滚")
            .content(String.format("%s 已回滚到版本 %s",
                release.getServiceName(), release.getPreviousTag()))
            .channels(List.of("feishu"))
            .build());
    }
}
```

## 三、服务管理

### 3.1 服务数据模型

```sql
-- 服务表
CREATE TABLE ops_service (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    service_name VARCHAR(100) NOT NULL COMMENT '服务名称',
    service_code VARCHAR(50) NOT NULL COMMENT '服务编码',
    service_type VARCHAR(20) NOT NULL COMMENT '服务类型: java/go/python/frontend',
    description VARCHAR(500) COMMENT '服务描述',
    git_repo VARCHAR(500) NOT NULL COMMENT 'Git 仓库地址',
    git_branch VARCHAR(100) DEFAULT 'master' COMMENT '默认分支',
    owner_id BIGINT NOT NULL COMMENT '负责人ID',
    team_id BIGINT COMMENT '团队ID',
    port INT COMMENT '服务端口',
    health_check VARCHAR(200) COMMENT '健康检查路径',
    status TINYINT DEFAULT 1 COMMENT '状态',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_code (service_code),
    KEY idx_owner (owner_id),
    KEY idx_team (team_id)
) COMMENT '服务表';

-- 服务环境配置表
CREATE TABLE ops_service_env (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    service_id BIGINT NOT NULL COMMENT '服务ID',
    env_id BIGINT NOT NULL COMMENT '环境ID',
    namespace VARCHAR(100) NOT NULL COMMENT 'K8s 命名空间',
    replicas INT DEFAULT 1 COMMENT '副本数',
    cpu_request VARCHAR(20) DEFAULT '100m' COMMENT 'CPU 请求',
    cpu_limit VARCHAR(20) DEFAULT '1000m' COMMENT 'CPU 限制',
    memory_request VARCHAR(20) DEFAULT '256Mi' COMMENT '内存请求',
    memory_limit VARCHAR(20) DEFAULT '1Gi' COMMENT '内存限制',
    env_vars TEXT COMMENT '环境变量 JSON',
    config_maps TEXT COMMENT 'ConfigMap 配置',
    secrets TEXT COMMENT 'Secret 配置',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_service_env (service_id, env_id)
) COMMENT '服务环境配置表';

-- 环境表
CREATE TABLE ops_environment (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    env_name VARCHAR(50) NOT NULL COMMENT '环境名称',
    env_code VARCHAR(20) NOT NULL COMMENT '环境编码: dev/test/staging/prod',
    cluster_id BIGINT NOT NULL COMMENT '集群ID',
    description VARCHAR(200) COMMENT '描述',
    sort INT DEFAULT 0 COMMENT '排序',
    status TINYINT DEFAULT 1 COMMENT '状态',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_code (env_code)
) COMMENT '环境表';
```

### 3.2 服务管理接口

```java
@RestController
@RequestMapping("/api/ops/services")
public class ServiceController {

    @Autowired
    private ServiceManageService serviceManageService;

    /**
     * 服务列表
     */
    @GetMapping
    public R<PageResult<ServiceVO>> list(ServiceQueryDTO query) {
        return R.ok(serviceManageService.page(query));
    }

    /**
     * 服务详情
     */
    @GetMapping("/{id}")
    public R<ServiceDetailVO> detail(@PathVariable Long id) {
        return R.ok(serviceManageService.getDetail(id));
    }

    /**
     * 服务运行状态
     */
    @GetMapping("/{id}/status")
    public R<ServiceStatusVO> status(@PathVariable Long id,
                                      @RequestParam Long envId) {
        return R.ok(serviceManageService.getStatus(id, envId));
    }

    /**
     * 服务 Pod 列表
     */
    @GetMapping("/{id}/pods")
    public R<List<PodVO>> pods(@PathVariable Long id,
                               @RequestParam Long envId) {
        return R.ok(serviceManageService.getPods(id, envId));
    }

    /**
     * 重启服务
     */
    @PostMapping("/{id}/restart")
    @AuditLog(module = "服务管理", action = "重启服务")
    public R<Void> restart(@PathVariable Long id,
                           @RequestParam Long envId) {
        serviceManageService.restart(id, envId);
        return R.ok();
    }

    /**
     * 扩缩容
     */
    @PostMapping("/{id}/scale")
    @AuditLog(module = "服务管理", action = "扩缩容")
    public R<Void> scale(@PathVariable Long id,
                         @RequestParam Long envId,
                         @RequestParam Integer replicas) {
        serviceManageService.scale(id, envId, replicas);
        return R.ok();
    }

    /**
     * 查看日志
     */
    @GetMapping("/{id}/logs")
    public R<String> logs(@PathVariable Long id,
                          @RequestParam Long envId,
                          @RequestParam(required = false) String podName,
                          @RequestParam(defaultValue = "100") Integer lines) {
        return R.ok(serviceManageService.getLogs(id, envId, podName, lines));
    }

    /**
     * 进入容器终端
     */
    @GetMapping("/{id}/terminal")
    public R<String> terminal(@PathVariable Long id,
                              @RequestParam Long envId,
                              @RequestParam String podName) {
        // 返回 WebSocket 连接地址
        return R.ok(serviceManageService.getTerminalUrl(id, envId, podName));
    }
}
```

## 四、调试工具

### 4.1 Arthas 集成

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              Arthas 调试能力                                         │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  实时监控:                       诊断分析:                   动态修改:              │
│  ├── dashboard    系统面板       ├── trace      方法追踪     ├── redefine  热更新   │
│  ├── thread       线程监控       ├── stack      调用栈       ├── mc/retrans 编译   │
│  ├── jvm          JVM 信息       ├── tt         时空隧道     ├── ognl      执行代码│
│  ├── memory       内存状态       ├── profiler   性能分析     └── watch     监控变量│
│  └── monitor      方法监控       └── heapdump   堆转储                              │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 调试服务

```java
// Arthas 调试服务
@Service
public class ArthasDebugService {

    @Autowired
    private KubernetesClient k8sClient;

    /**
     * 在指定 Pod 启动 Arthas
     */
    public ArthasSessionVO startArthas(String namespace, String podName, String container) {
        // 1. 下载 Arthas
        String downloadCmd = "curl -O https://arthas.aliyun.com/arthas-boot.jar";

        // 2. 启动 Arthas
        String startCmd = "java -jar arthas-boot.jar --telnet-port 3658 --http-port 8563";

        // 执行命令
        ExecWatch exec = k8sClient.pods()
            .inNamespace(namespace)
            .withName(podName)
            .inContainer(container)
            .writingOutput(System.out)
            .exec("sh", "-c", downloadCmd + " && " + startCmd);

        // 3. 返回会话信息
        return ArthasSessionVO.builder()
            .sessionId(UUID.randomUUID().toString())
            .podName(podName)
            .telnetPort(3658)
            .httpPort(8563)
            .tunnelUrl(String.format("ws://arthas-tunnel:7777/ws?method=connectArthas&id=%s", podName))
            .build();
    }

    /**
     * 执行 Arthas 命令
     */
    public String executeCommand(String sessionId, String command) {
        // 通过 Arthas Tunnel 执行命令
        // ...
        return result;
    }

    /**
     * 方法追踪
     */
    public void trace(String sessionId, String className, String methodName, int maxDepth) {
        String command = String.format("trace %s %s -n 5 --skipJDKMethod false",
            className, methodName);
        executeCommand(sessionId, command);
    }

    /**
     * 监控方法调用
     */
    public void watch(String sessionId, String className, String methodName, String express) {
        String command = String.format("watch %s %s \"%s\" -n 5 -x 3",
            className, methodName, express);
        executeCommand(sessionId, command);
    }

    /**
     * 性能分析
     */
    public String profiler(String sessionId, String action, int duration) {
        String command = String.format("profiler %s --duration %d --format html",
            action, duration);
        return executeCommand(sessionId, command);
    }
}
```

### 4.3 远程调试

```java
// 远程调试服务
@Service
public class RemoteDebugService {

    @Autowired
    private KubernetesClient k8sClient;

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    /**
     * 开启远程调试
     */
    public DebugSessionVO enableDebug(String namespace, String podName, String debugSecret) {
        // 1. 验证调试密钥
        String expectedSecret = (String) redisTemplate.opsForValue().get("debug:secret:" + podName);
        if (!debugSecret.equals(expectedSecret)) {
            throw new BizException("调试密钥错误");
        }

        // 2. 修改 Deployment 添加调试参数
        k8sClient.apps().deployments()
            .inNamespace(namespace)
            .withName(getDeploymentName(podName))
            .edit(d -> {
                Container container = d.getSpec().getTemplate().getSpec().getContainers().get(0);

                // 添加 JDWP 参数
                String javaOpts = container.getEnv().stream()
                    .filter(e -> "JAVA_OPTS".equals(e.getName()))
                    .findFirst()
                    .map(EnvVar::getValue)
                    .orElse("");

                String debugOpts = "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005";
                container.getEnv().add(new EnvVarBuilder()
                    .withName("JAVA_OPTS")
                    .withValue(javaOpts + " " + debugOpts)
                    .build());

                // 添加调试端口
                container.getPorts().add(new ContainerPortBuilder()
                    .withName("debug")
                    .withContainerPort(5005)
                    .build());

                return d;
            });

        // 3. 创建端口转发
        String sessionId = UUID.randomUUID().toString();
        int localPort = allocatePort();

        // 4. 设置会话过期时间
        redisTemplate.opsForValue().set("debug:session:" + sessionId, podName, 2, TimeUnit.HOURS);

        return DebugSessionVO.builder()
            .sessionId(sessionId)
            .debugPort(localPort)
            .expireTime(LocalDateTime.now().plusHours(2))
            .build();
    }

    /**
     * 关闭远程调试
     */
    public void disableDebug(String sessionId) {
        String podName = (String) redisTemplate.opsForValue().get("debug:session:" + sessionId);
        if (podName == null) {
            return;
        }

        // 移除调试参数并重启 Pod
        // ...

        redisTemplate.delete("debug:session:" + sessionId);
    }

    /**
     * 生成调试密钥
     */
    public String generateDebugSecret(String podName) {
        String secret = UUID.randomUUID().toString().substring(0, 8);
        redisTemplate.opsForValue().set("debug:secret:" + podName, secret, 10, TimeUnit.MINUTES);
        return secret;
    }
}
```

## 五、配置中心 UI

### 5.1 配置管理

```java
@RestController
@RequestMapping("/api/ops/configs")
public class ConfigController {

    @Autowired
    private NacosConfigService nacosConfigService;

    /**
     * 配置列表
     */
    @GetMapping
    public R<PageResult<ConfigVO>> list(ConfigQueryDTO query) {
        return R.ok(nacosConfigService.page(query));
    }

    /**
     * 获取配置内容
     */
    @GetMapping("/{dataId}")
    public R<ConfigDetailVO> get(@PathVariable String dataId,
                                  @RequestParam String group,
                                  @RequestParam(required = false) String namespace) {
        return R.ok(nacosConfigService.getConfig(dataId, group, namespace));
    }

    /**
     * 发布配置
     */
    @PostMapping
    @AuditLog(module = "配置管理", action = "发布配置")
    public R<Void> publish(@RequestBody @Valid ConfigPublishDTO dto) {
        nacosConfigService.publishConfig(dto);
        return R.ok();
    }

    /**
     * 配置历史
     */
    @GetMapping("/{dataId}/history")
    public R<List<ConfigHistoryVO>> history(@PathVariable String dataId,
                                             @RequestParam String group) {
        return R.ok(nacosConfigService.getHistory(dataId, group));
    }

    /**
     * 回滚配置
     */
    @PostMapping("/{dataId}/rollback")
    @AuditLog(module = "配置管理", action = "回滚配置")
    public R<Void> rollback(@PathVariable String dataId,
                            @RequestParam String group,
                            @RequestParam Long historyId) {
        nacosConfigService.rollback(dataId, group, historyId);
        return R.ok();
    }

    /**
     * 配置对比
     */
    @GetMapping("/{dataId}/diff")
    public R<ConfigDiffVO> diff(@PathVariable String dataId,
                                 @RequestParam String group,
                                 @RequestParam Long historyId1,
                                 @RequestParam Long historyId2) {
        return R.ok(nacosConfigService.diff(dataId, group, historyId1, historyId2));
    }

    /**
     * 监听者列表
     */
    @GetMapping("/{dataId}/listeners")
    public R<List<ListenerVO>> listeners(@PathVariable String dataId,
                                          @RequestParam String group) {
        return R.ok(nacosConfigService.getListeners(dataId, group));
    }
}
```

## 六、资源管理

### 6.1 资源概览

```java
@RestController
@RequestMapping("/api/ops/resources")
public class ResourceController {

    @Autowired
    private ResourceService resourceService;

    /**
     * 集群资源概览
     */
    @GetMapping("/overview")
    public R<ClusterOverviewVO> overview(@RequestParam Long clusterId) {
        return R.ok(resourceService.getClusterOverview(clusterId));
    }

    /**
     * 节点列表
     */
    @GetMapping("/nodes")
    public R<List<NodeVO>> nodes(@RequestParam Long clusterId) {
        return R.ok(resourceService.getNodes(clusterId));
    }

    /**
     * 节点详情
     */
    @GetMapping("/nodes/{nodeName}")
    public R<NodeDetailVO> nodeDetail(@RequestParam Long clusterId,
                                       @PathVariable String nodeName) {
        return R.ok(resourceService.getNodeDetail(clusterId, nodeName));
    }

    /**
     * 命名空间列表
     */
    @GetMapping("/namespaces")
    public R<List<NamespaceVO>> namespaces(@RequestParam Long clusterId) {
        return R.ok(resourceService.getNamespaces(clusterId));
    }

    /**
     * 资源配额
     */
    @GetMapping("/quotas")
    public R<List<ResourceQuotaVO>> quotas(@RequestParam Long clusterId,
                                            @RequestParam String namespace) {
        return R.ok(resourceService.getResourceQuotas(clusterId, namespace));
    }
}

// 资源服务
@Service
public class ResourceService {

    @Autowired
    private KubernetesClient k8sClient;

    public ClusterOverviewVO getClusterOverview(Long clusterId) {
        NodeList nodes = k8sClient.nodes().list();

        // 统计资源
        long totalCpu = 0, usedCpu = 0;
        long totalMemory = 0, usedMemory = 0;
        int totalPods = 0, runningPods = 0;

        for (Node node : nodes.getItems()) {
            NodeStatus status = node.getStatus();

            // CPU
            Quantity cpuCapacity = status.getCapacity().get("cpu");
            totalCpu += parseCpu(cpuCapacity);

            // 内存
            Quantity memCapacity = status.getCapacity().get("memory");
            totalMemory += parseMemory(memCapacity);
        }

        // Pod 统计
        PodList pods = k8sClient.pods().inAnyNamespace().list();
        totalPods = pods.getItems().size();
        runningPods = (int) pods.getItems().stream()
            .filter(p -> "Running".equals(p.getStatus().getPhase()))
            .count();

        return ClusterOverviewVO.builder()
            .nodeCount(nodes.getItems().size())
            .totalCpu(totalCpu)
            .usedCpu(usedCpu)
            .cpuUsagePercent((double) usedCpu / totalCpu * 100)
            .totalMemory(totalMemory)
            .usedMemory(usedMemory)
            .memoryUsagePercent((double) usedMemory / totalMemory * 100)
            .totalPods(totalPods)
            .runningPods(runningPods)
            .build();
    }
}
```

## 七、告警管理

### 7.1 告警中心

```java
@RestController
@RequestMapping("/api/ops/alerts")
public class AlertController {

    @Autowired
    private AlertService alertService;

    /**
     * 告警列表
     */
    @GetMapping
    public R<PageResult<AlertVO>> list(AlertQueryDTO query) {
        return R.ok(alertService.page(query));
    }

    /**
     * 告警统计
     */
    @GetMapping("/stats")
    public R<AlertStatsVO> stats(@RequestParam(required = false) String timeRange) {
        return R.ok(alertService.getStats(timeRange));
    }

    /**
     * 确认告警
     */
    @PostMapping("/{id}/ack")
    @AuditLog(module = "告警管理", action = "确认告警")
    public R<Void> acknowledge(@PathVariable Long id,
                               @RequestBody AckDTO dto) {
        alertService.acknowledge(id, dto);
        return R.ok();
    }

    /**
     * 关闭告警
     */
    @PostMapping("/{id}/close")
    @AuditLog(module = "告警管理", action = "关闭告警")
    public R<Void> close(@PathVariable Long id,
                         @RequestBody CloseDTO dto) {
        alertService.close(id, dto);
        return R.ok();
    }

    /**
     * 告警规则列表
     */
    @GetMapping("/rules")
    public R<List<AlertRuleVO>> rules() {
        return R.ok(alertService.getRules());
    }

    /**
     * 创建/更新告警规则
     */
    @PostMapping("/rules")
    @AuditLog(module = "告警管理", action = "配置告警规则")
    public R<Void> saveRule(@RequestBody @Valid AlertRuleDTO dto) {
        alertService.saveRule(dto);
        return R.ok();
    }

    /**
     * 告警通知策略
     */
    @GetMapping("/policies")
    public R<List<AlertPolicyVO>> policies() {
        return R.ok(alertService.getPolicies());
    }

    /**
     * 配置通知策略
     */
    @PostMapping("/policies")
    @AuditLog(module = "告警管理", action = "配置通知策略")
    public R<Void> savePolicy(@RequestBody @Valid AlertPolicyDTO dto) {
        alertService.savePolicy(dto);
        return R.ok();
    }
}
```

## 八、WebSocket 终端

### 8.1 终端服务

```java
// 终端 WebSocket
@ServerEndpoint("/ws/terminal/{sessionId}")
@Component
public class TerminalWebSocket {

    private static final Map<String, TerminalSession> SESSIONS = new ConcurrentHashMap<>();

    @OnOpen
    public void onOpen(Session session, @PathParam("sessionId") String sessionId) {
        TerminalSession terminalSession = new TerminalSession(session, sessionId);
        SESSIONS.put(sessionId, terminalSession);

        // 连接到 K8s Pod
        terminalSession.connect();
    }

    @OnMessage
    public void onMessage(String message, Session session) {
        TerminalSession terminalSession = SESSIONS.get(getSessionId(session));
        if (terminalSession != null) {
            terminalSession.send(message);
        }
    }

    @OnClose
    public void onClose(Session session) {
        String sessionId = getSessionId(session);
        TerminalSession terminalSession = SESSIONS.remove(sessionId);
        if (terminalSession != null) {
            terminalSession.close();
        }
    }

    @OnError
    public void onError(Session session, Throwable error) {
        log.error("Terminal WebSocket error", error);
        onClose(session);
    }
}

// 终端会话
public class TerminalSession {

    private final Session webSocketSession;
    private final String sessionId;
    private ExecWatch execWatch;

    public TerminalSession(Session session, String sessionId) {
        this.webSocketSession = session;
        this.sessionId = sessionId;
    }

    public void connect() {
        // 从 Redis 获取会话信息
        TerminalInfo info = getTerminalInfo(sessionId);

        // 连接到 Pod
        execWatch = k8sClient.pods()
            .inNamespace(info.getNamespace())
            .withName(info.getPodName())
            .inContainer(info.getContainer())
            .redirectingInput()
            .redirectingOutput()
            .redirectingError()
            .withTTY()
            .exec("sh");

        // 启动输出读取线程
        new Thread(() -> {
            try (InputStream is = execWatch.getOutput()) {
                byte[] buffer = new byte[1024];
                int len;
                while ((len = is.read(buffer)) != -1) {
                    String output = new String(buffer, 0, len, StandardCharsets.UTF_8);
                    sendToClient(output);
                }
            } catch (Exception e) {
                log.error("Read output error", e);
            }
        }).start();
    }

    public void send(String input) {
        try {
            execWatch.getInput().write(input.getBytes(StandardCharsets.UTF_8));
            execWatch.getInput().flush();
        } catch (Exception e) {
            log.error("Send input error", e);
        }
    }

    public void close() {
        if (execWatch != null) {
            execWatch.close();
        }
    }

    private void sendToClient(String message) {
        try {
            webSocketSession.getBasicRemote().sendText(message);
        } catch (Exception e) {
            log.error("Send to client error", e);
        }
    }
}
```

## 九、操作审计

### 9.1 操作日志

```sql
-- 操作日志表
CREATE TABLE ops_audit_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    module VARCHAR(50) NOT NULL COMMENT '模块',
    action VARCHAR(100) NOT NULL COMMENT '操作',
    operator_id BIGINT NOT NULL COMMENT '操作人ID',
    operator_name VARCHAR(50) NOT NULL COMMENT '操作人',
    target_type VARCHAR(50) COMMENT '目标类型',
    target_id VARCHAR(100) COMMENT '目标ID',
    target_name VARCHAR(200) COMMENT '目标名称',
    request_method VARCHAR(10) COMMENT '请求方法',
    request_uri VARCHAR(500) COMMENT '请求URI',
    request_params TEXT COMMENT '请求参数',
    response_code INT COMMENT '响应码',
    response_msg TEXT COMMENT '响应消息',
    client_ip VARCHAR(50) COMMENT '客户端IP',
    user_agent VARCHAR(500) COMMENT 'User-Agent',
    duration INT COMMENT '耗时(ms)',
    status TINYINT COMMENT '状态: 1成功 0失败',
    error_msg TEXT COMMENT '错误信息',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_module (module),
    KEY idx_operator (operator_id),
    KEY idx_target (target_type, target_id),
    KEY idx_time (create_time)
) COMMENT '操作日志表';
```

### 9.2 审计查询

```java
@RestController
@RequestMapping("/api/ops/audit")
public class AuditController {

    @Autowired
    private AuditLogService auditLogService;

    /**
     * 审计日志列表
     */
    @GetMapping("/logs")
    public R<PageResult<AuditLogVO>> logs(AuditLogQueryDTO query) {
        return R.ok(auditLogService.page(query));
    }

    /**
     * 操作统计
     */
    @GetMapping("/stats")
    public R<AuditStatsVO> stats(@RequestParam String startTime,
                                  @RequestParam String endTime) {
        return R.ok(auditLogService.getStats(startTime, endTime));
    }

    /**
     * 导出审计日志
     */
    @GetMapping("/export")
    public void export(AuditLogQueryDTO query, HttpServletResponse response) {
        auditLogService.export(query, response);
    }
}
```
