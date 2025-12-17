# 15 - 采集服务重构设计

## 一、现状分析与问题

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              采集服务现状问题                                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  当前架构:                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  定时器 ──▶ 采集服务(4类型) ──▶ RabbitMQ ──▶ MySQL状态表                     │   │
│  │            ├── 用例采集                                                      │   │
│  │            ├── 需求采集                                                      │   │
│  │            ├── 缺陷采集                                                      │   │
│  │            └── 度量采集                                                      │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  核心痛点:                                                                          │
│  ┌───────────────┬────────────────────────────────────────────────────────────┐    │
│  │ 1. 流程复杂    │ 多接口采集、父子数据、不同类型、不同计算逻辑              │    │
│  │ 2. 运行时长    │ 数小时运行，中断需大范围重来                              │    │
│  │ 3. 状态管理    │ MySQL状态表，无法精细追踪，不支持断点续传                 │    │
│  │ 4. 配置复杂    │ 版本→小版本→小小版本，JSON参数配置                        │    │
│  │ 5. 无流程监控  │ 不知道执行到哪一步，出错难定位                            │    │
│  │ 6. 日志分散    │ 5台服务器，逐台查找日志                                   │    │
│  │ 7. 不可视化    │ 资源/文档/服务/配置无法快速查看                           │    │
│  └───────────────┴────────────────────────────────────────────────────────────┘    │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、重构目标架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              采集服务重构架构                                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           触发层                                             │   │
│  │  XXL-JOB 定时调度 │ API 手动触发 │ 消息触发 │ Webhook 触发                  │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           编排层 (工作流引擎)                                │   │
│  │  ┌───────────────────────────────────────────────────────────────────────┐ │   │
│  │  │  采集流程定义 (DAG)                                                    │ │   │
│  │  │  ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐                 │ │   │
│  │  │  │初始化│───▶│获取源│───▶│数据采集│───▶│数据处理│───▶│结果存储│        │ │   │
│  │  │  └─────┘    └─────┘    └─────┘    └─────┘    └─────┘                 │ │   │
│  │  │       │          │          │          │          │                   │ │   │
│  │  │       ▼          ▼          ▼          ▼          ▼                   │ │   │
│  │  │  [检查点]    [检查点]    [检查点]    [检查点]    [检查点]              │ │   │
│  │  └───────────────────────────────────────────────────────────────────────┘ │   │
│  │  支持: 断点续传 │ 并行执行 │ 条件分支 │ 重试机制 │ 超时控制               │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           执行层 (采集任务)                                  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │   │
│  │  │ 用例采集器  │  │ 需求采集器  │  │ 缺陷采集器  │  │ 度量采集器  │        │   │
│  │  │ (TestCase)  │  │ (Requirement)│ │ (Defect)    │  │ (Metric)    │        │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           监控层                                             │   │
│  │  流程监控 │ 进度追踪 │ 日志聚合 │ 告警通知 │ 统计分析                       │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 三、工作流引擎设计

### 3.1 流程定义 DSL

```yaml
# 用例采集流程定义
workflow:
  name: testcase-collection
  version: "1.0"
  description: "测试用例采集流程"

  # 输入参数
  inputs:
    - name: projectId
      type: string
      required: true
    - name: versionId
      type: string
      required: false
    - name: startDate
      type: date
      required: true
    - name: endDate
      type: date
      required: true

  # 全局配置
  config:
    timeout: 3600         # 总超时时间(秒)
    retryCount: 3         # 默认重试次数
    retryInterval: 60     # 重试间隔(秒)
    checkpointEnabled: true

  # 步骤定义
  steps:
    # 初始化
    - id: init
      name: 初始化
      type: task
      handler: InitHandler
      config:
        timeout: 60

    # 获取项目配置
    - id: getProjectConfig
      name: 获取项目配置
      type: task
      handler: GetProjectConfigHandler
      dependsOn: [init]
      config:
        timeout: 30

    # 获取版本列表
    - id: getVersions
      name: 获取版本列表
      type: task
      handler: GetVersionsHandler
      dependsOn: [getProjectConfig]
      config:
        timeout: 120

    # 并行采集用例 (按版本分片)
    - id: collectByVersions
      name: 按版本采集
      type: parallel
      dependsOn: [getVersions]
      forEach: ${versions}
      parallelism: 5
      steps:
        - id: collectVersion
          name: 采集版本用例
          type: subWorkflow
          workflow: version-testcase-collection
          inputs:
            versionId: ${item.id}
            projectId: ${projectId}

    # 数据聚合
    - id: aggregate
      name: 数据聚合
      type: task
      handler: AggregateHandler
      dependsOn: [collectByVersions]
      config:
        timeout: 300

    # 计算度量
    - id: calculate
      name: 计算度量
      type: task
      handler: CalculateMetricsHandler
      dependsOn: [aggregate]
      config:
        timeout: 600

    # 存储结果
    - id: saveResult
      name: 存储结果
      type: task
      handler: SaveResultHandler
      dependsOn: [calculate]
      config:
        timeout: 300

    # 发送通知
    - id: notify
      name: 发送通知
      type: task
      handler: NotifyHandler
      dependsOn: [saveResult]
      config:
        onFailure: continue  # 失败继续

  # 错误处理
  onError:
    - type: retry
      maxAttempts: 3
      backoff:
        initial: 30
        multiplier: 2
    - type: notify
      channels: [feishu, email]
```

### 3.2 数据模型

```sql
-- 工作流定义表
CREATE TABLE wf_workflow_definition (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    workflow_code VARCHAR(100) NOT NULL COMMENT '工作流编码',
    workflow_name VARCHAR(200) NOT NULL COMMENT '工作流名称',
    version VARCHAR(20) NOT NULL COMMENT '版本号',
    description VARCHAR(500) COMMENT '描述',
    definition_json LONGTEXT NOT NULL COMMENT '流程定义JSON',
    status TINYINT DEFAULT 1 COMMENT '状态: 0禁用 1启用',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_code_version (workflow_code, version)
) COMMENT '工作流定义表';

-- 工作流实例表
CREATE TABLE wf_workflow_instance (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    instance_no VARCHAR(50) NOT NULL COMMENT '实例编号',
    workflow_id BIGINT NOT NULL COMMENT '工作流定义ID',
    workflow_code VARCHAR(100) NOT NULL COMMENT '工作流编码',
    trigger_type VARCHAR(20) NOT NULL COMMENT '触发类型: schedule/manual/message/webhook',
    input_params TEXT COMMENT '输入参数JSON',
    status VARCHAR(20) NOT NULL COMMENT '状态: pending/running/paused/success/failed/cancelled',
    progress INT DEFAULT 0 COMMENT '进度百分比',
    current_step_id VARCHAR(50) COMMENT '当前步骤ID',
    start_time DATETIME COMMENT '开始时间',
    end_time DATETIME COMMENT '结束时间',
    duration INT COMMENT '耗时(秒)',
    error_msg TEXT COMMENT '错误信息',
    retry_count INT DEFAULT 0 COMMENT '重试次数',
    create_by BIGINT COMMENT '创建人',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_instance_no (instance_no),
    KEY idx_workflow (workflow_id),
    KEY idx_status (status),
    KEY idx_create_time (create_time)
) COMMENT '工作流实例表';

-- 步骤执行记录表
CREATE TABLE wf_step_execution (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    instance_id BIGINT NOT NULL COMMENT '实例ID',
    step_id VARCHAR(50) NOT NULL COMMENT '步骤ID',
    step_name VARCHAR(100) NOT NULL COMMENT '步骤名称',
    step_type VARCHAR(20) NOT NULL COMMENT '步骤类型',
    status VARCHAR(20) NOT NULL COMMENT '状态',
    input_data TEXT COMMENT '输入数据',
    output_data TEXT COMMENT '输出数据',
    start_time DATETIME COMMENT '开始时间',
    end_time DATETIME COMMENT '结束时间',
    duration INT COMMENT '耗时(秒)',
    retry_count INT DEFAULT 0 COMMENT '重试次数',
    error_msg TEXT COMMENT '错误信息',
    checkpoint_data LONGTEXT COMMENT '检查点数据',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_instance (instance_id),
    KEY idx_step (step_id),
    KEY idx_status (status)
) COMMENT '步骤执行记录表';

-- 检查点表
CREATE TABLE wf_checkpoint (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    instance_id BIGINT NOT NULL COMMENT '实例ID',
    step_id VARCHAR(50) NOT NULL COMMENT '步骤ID',
    checkpoint_key VARCHAR(100) NOT NULL COMMENT '检查点键',
    checkpoint_data LONGTEXT NOT NULL COMMENT '检查点数据',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_instance_step_key (instance_id, step_id, checkpoint_key)
) COMMENT '检查点表';

-- 采集任务表
CREATE TABLE collect_task (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    task_no VARCHAR(50) NOT NULL COMMENT '任务编号',
    task_type VARCHAR(20) NOT NULL COMMENT '任务类型: testcase/requirement/defect/metric',
    project_id VARCHAR(50) NOT NULL COMMENT '项目ID',
    version_id VARCHAR(50) COMMENT '版本ID',
    config_json TEXT COMMENT '配置参数JSON',
    workflow_instance_id BIGINT COMMENT '工作流实例ID',
    status VARCHAR(20) NOT NULL COMMENT '状态',
    total_count INT DEFAULT 0 COMMENT '总数量',
    success_count INT DEFAULT 0 COMMENT '成功数量',
    fail_count INT DEFAULT 0 COMMENT '失败数量',
    start_time DATETIME COMMENT '开始时间',
    end_time DATETIME COMMENT '结束时间',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_task_no (task_no),
    KEY idx_project (project_id),
    KEY idx_type (task_type),
    KEY idx_status (status)
) COMMENT '采集任务表';

-- 采集记录表 (详细记录每条数据的采集状态)
CREATE TABLE collect_record (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    task_id BIGINT NOT NULL COMMENT '任务ID',
    source_id VARCHAR(100) NOT NULL COMMENT '源数据ID',
    source_type VARCHAR(20) NOT NULL COMMENT '数据类型',
    parent_id VARCHAR(100) COMMENT '父数据ID',
    data_json TEXT COMMENT '数据内容',
    status VARCHAR(20) NOT NULL COMMENT '状态: pending/success/failed/skipped',
    error_msg VARCHAR(500) COMMENT '错误信息',
    retry_count INT DEFAULT 0 COMMENT '重试次数',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_task (task_id),
    KEY idx_source (source_id),
    KEY idx_status (status)
) COMMENT '采集记录表';
```

### 3.3 工作流引擎实现

```java
// 工作流引擎核心
@Service
public class WorkflowEngine {

    @Autowired
    private WorkflowDefinitionRepository definitionRepo;

    @Autowired
    private WorkflowInstanceRepository instanceRepo;

    @Autowired
    private StepExecutionRepository stepExecutionRepo;

    @Autowired
    private CheckpointRepository checkpointRepo;

    @Autowired
    private Map<String, StepHandler> handlerMap;

    @Autowired
    private ThreadPoolTaskExecutor taskExecutor;

    /**
     * 启动工作流
     */
    @Transactional
    public String startWorkflow(String workflowCode, Map<String, Object> inputs) {
        // 1. 获取工作流定义
        WorkflowDefinition definition = definitionRepo.findLatestByCode(workflowCode);
        if (definition == null) {
            throw new BizException("工作流不存在: " + workflowCode);
        }

        // 2. 创建实例
        WorkflowInstance instance = WorkflowInstance.builder()
            .instanceNo(generateInstanceNo())
            .workflowId(definition.getId())
            .workflowCode(workflowCode)
            .triggerType("manual")
            .inputParams(JsonUtils.toJson(inputs))
            .status(WorkflowStatus.PENDING)
            .progress(0)
            .build();
        instanceRepo.save(instance);

        // 3. 异步执行
        taskExecutor.execute(() -> executeWorkflow(instance.getId()));

        return instance.getInstanceNo();
    }

    /**
     * 恢复工作流 (断点续传)
     */
    public void resumeWorkflow(Long instanceId) {
        WorkflowInstance instance = instanceRepo.findById(instanceId)
            .orElseThrow(() -> new BizException("实例不存在"));

        if (instance.getStatus() != WorkflowStatus.PAUSED &&
            instance.getStatus() != WorkflowStatus.FAILED) {
            throw new BizException("实例状态不支持恢复");
        }

        // 更新状态
        instance.setStatus(WorkflowStatus.RUNNING);
        instanceRepo.save(instance);

        // 从当前步骤继续执行
        taskExecutor.execute(() -> executeFromStep(instance.getId(), instance.getCurrentStepId()));
    }

    /**
     * 执行工作流
     */
    private void executeWorkflow(Long instanceId) {
        WorkflowInstance instance = instanceRepo.findById(instanceId).orElseThrow();
        WorkflowDefinition definition = definitionRepo.findById(instance.getWorkflowId()).orElseThrow();

        try {
            // 解析流程定义
            WorkflowDef workflowDef = parseDefinition(definition.getDefinitionJson());
            Map<String, Object> context = new HashMap<>();
            context.putAll(JsonUtils.parseMap(instance.getInputParams()));

            // 更新状态
            instance.setStatus(WorkflowStatus.RUNNING);
            instance.setStartTime(LocalDateTime.now());
            instanceRepo.save(instance);

            // 执行步骤
            List<StepDef> steps = workflowDef.getSteps();
            for (int i = 0; i < steps.size(); i++) {
                StepDef step = steps.get(i);

                // 检查依赖
                if (!checkDependencies(instanceId, step.getDependsOn())) {
                    continue;
                }

                // 执行步骤
                executeStep(instance, step, context);

                // 更新进度
                instance.setProgress((i + 1) * 100 / steps.size());
                instance.setCurrentStepId(step.getId());
                instanceRepo.save(instance);
            }

            // 成功完成
            instance.setStatus(WorkflowStatus.SUCCESS);
            instance.setEndTime(LocalDateTime.now());
            instance.setDuration(calculateDuration(instance));
            instance.setProgress(100);
            instanceRepo.save(instance);

        } catch (Exception e) {
            // 执行失败
            instance.setStatus(WorkflowStatus.FAILED);
            instance.setEndTime(LocalDateTime.now());
            instance.setErrorMsg(e.getMessage());
            instanceRepo.save(instance);

            // 发送告警
            sendAlert(instance, e);
        }
    }

    /**
     * 执行步骤
     */
    private void executeStep(WorkflowInstance instance, StepDef step, Map<String, Object> context) {
        // 创建步骤执行记录
        StepExecution execution = StepExecution.builder()
            .instanceId(instance.getId())
            .stepId(step.getId())
            .stepName(step.getName())
            .stepType(step.getType())
            .status(StepStatus.RUNNING)
            .inputData(JsonUtils.toJson(context))
            .startTime(LocalDateTime.now())
            .build();
        stepExecutionRepo.save(execution);

        try {
            // 检查是否有检查点
            Checkpoint checkpoint = checkpointRepo.findLatest(instance.getId(), step.getId());
            if (checkpoint != null) {
                context.put("_checkpoint", JsonUtils.parseMap(checkpoint.getCheckpointData()));
            }

            // 获取处理器
            StepHandler handler = handlerMap.get(step.getHandler());
            if (handler == null) {
                throw new BizException("步骤处理器不存在: " + step.getHandler());
            }

            // 执行
            StepResult result = handler.execute(new StepContext(instance, step, context, this));

            // 更新执行记录
            execution.setStatus(StepStatus.SUCCESS);
            execution.setOutputData(JsonUtils.toJson(result.getOutput()));
            execution.setEndTime(LocalDateTime.now());
            stepExecutionRepo.save(execution);

            // 合并输出到上下文
            context.putAll(result.getOutput());

        } catch (Exception e) {
            // 重试处理
            if (execution.getRetryCount() < step.getConfig().getRetryCount()) {
                execution.setRetryCount(execution.getRetryCount() + 1);
                stepExecutionRepo.save(execution);

                // 等待后重试
                Thread.sleep(step.getConfig().getRetryInterval() * 1000L);
                executeStep(instance, step, context);
            } else {
                execution.setStatus(StepStatus.FAILED);
                execution.setErrorMsg(e.getMessage());
                execution.setEndTime(LocalDateTime.now());
                stepExecutionRepo.save(execution);
                throw e;
            }
        }
    }

    /**
     * 保存检查点
     */
    public void saveCheckpoint(Long instanceId, String stepId, String key, Map<String, Object> data) {
        Checkpoint checkpoint = new Checkpoint();
        checkpoint.setInstanceId(instanceId);
        checkpoint.setStepId(stepId);
        checkpoint.setCheckpointKey(key);
        checkpoint.setCheckpointData(JsonUtils.toJson(data));
        checkpointRepo.save(checkpoint);
    }
}
```

### 3.4 采集器实现

```java
// 采集器基类
public abstract class AbstractCollector<T> implements StepHandler {

    @Autowired
    protected CollectTaskRepository taskRepo;

    @Autowired
    protected CollectRecordRepository recordRepo;

    @Autowired
    protected WorkflowEngine workflowEngine;

    @Override
    public StepResult execute(StepContext context) {
        CollectTask task = getOrCreateTask(context);
        Map<String, Object> checkpoint = context.getCheckpoint();

        try {
            // 获取数据源列表
            List<String> sourceIds = getSourceIds(context);

            // 检查点: 从上次中断位置继续
            int startIndex = 0;
            if (checkpoint != null && checkpoint.containsKey("lastIndex")) {
                startIndex = (Integer) checkpoint.get("lastIndex");
            }

            // 分批处理
            int batchSize = getBatchSize();
            for (int i = startIndex; i < sourceIds.size(); i += batchSize) {
                List<String> batch = sourceIds.subList(i, Math.min(i + batchSize, sourceIds.size()));

                // 采集数据
                List<T> dataList = collectBatch(context, batch);

                // 处理数据
                processBatch(context, task, dataList);

                // 保存检查点
                workflowEngine.saveCheckpoint(
                    context.getInstance().getId(),
                    context.getStep().getId(),
                    "progress",
                    Map.of("lastIndex", i + batchSize, "processedCount", task.getSuccessCount())
                );

                // 更新任务进度
                task.setSuccessCount(task.getSuccessCount() + dataList.size());
                taskRepo.save(task);
            }

            // 完成
            task.setStatus(CollectStatus.SUCCESS);
            task.setEndTime(LocalDateTime.now());
            taskRepo.save(task);

            return StepResult.success(Map.of(
                "taskId", task.getId(),
                "totalCount", task.getTotalCount(),
                "successCount", task.getSuccessCount()
            ));

        } catch (Exception e) {
            task.setStatus(CollectStatus.FAILED);
            taskRepo.save(task);
            throw e;
        }
    }

    /**
     * 获取源数据ID列表
     */
    protected abstract List<String> getSourceIds(StepContext context);

    /**
     * 批量采集数据
     */
    protected abstract List<T> collectBatch(StepContext context, List<String> sourceIds);

    /**
     * 处理数据
     */
    protected abstract void processBatch(StepContext context, CollectTask task, List<T> dataList);

    /**
     * 批次大小
     */
    protected int getBatchSize() {
        return 100;
    }
}

// 测试用例采集器
@Component("TestCaseCollector")
public class TestCaseCollector extends AbstractCollector<TestCaseDTO> {

    @Autowired
    private ExternalTestCaseApi externalApi;

    @Autowired
    private TestCaseService testCaseService;

    @Override
    protected List<String> getSourceIds(StepContext context) {
        String projectId = context.getInput("projectId");
        String versionId = context.getInput("versionId");

        // 获取用例ID列表
        return externalApi.getTestCaseIds(projectId, versionId);
    }

    @Override
    protected List<TestCaseDTO> collectBatch(StepContext context, List<String> sourceIds) {
        return externalApi.getTestCases(sourceIds);
    }

    @Override
    protected void processBatch(StepContext context, CollectTask task, List<TestCaseDTO> dataList) {
        for (TestCaseDTO dto : dataList) {
            try {
                // 转换并保存
                TestCase testCase = convertToEntity(dto);
                testCaseService.saveOrUpdate(testCase);

                // 记录成功
                saveRecord(task, dto.getId(), "testcase", CollectRecordStatus.SUCCESS, null);

                // 处理子数据 (测试步骤)
                if (dto.getSteps() != null) {
                    for (TestStepDTO step : dto.getSteps()) {
                        TestStep testStep = convertToStepEntity(step, testCase.getId());
                        testCaseService.saveStep(testStep);
                    }
                }

            } catch (Exception e) {
                // 记录失败
                saveRecord(task, dto.getId(), "testcase", CollectRecordStatus.FAILED, e.getMessage());
                task.setFailCount(task.getFailCount() + 1);
            }
        }
    }

    private void saveRecord(CollectTask task, String sourceId, String type, CollectRecordStatus status, String error) {
        CollectRecord record = CollectRecord.builder()
            .taskId(task.getId())
            .sourceId(sourceId)
            .sourceType(type)
            .status(status)
            .errorMsg(error)
            .build();
        recordRepo.save(record);
    }
}

// 需求采集器
@Component("RequirementCollector")
public class RequirementCollector extends AbstractCollector<RequirementDTO> {

    @Autowired
    private ExternalRequirementApi externalApi;

    @Autowired
    private RequirementService requirementService;

    @Override
    protected List<String> getSourceIds(StepContext context) {
        String projectId = context.getInput("projectId");
        Date startDate = context.getInput("startDate");
        Date endDate = context.getInput("endDate");

        return externalApi.getRequirementIds(projectId, startDate, endDate);
    }

    @Override
    protected List<RequirementDTO> collectBatch(StepContext context, List<String> sourceIds) {
        return externalApi.getRequirements(sourceIds);
    }

    @Override
    protected void processBatch(StepContext context, CollectTask task, List<RequirementDTO> dataList) {
        // 处理父子关系
        Map<String, RequirementDTO> parentMap = new HashMap<>();
        List<RequirementDTO> children = new ArrayList<>();

        for (RequirementDTO dto : dataList) {
            if (dto.getParentId() == null) {
                parentMap.put(dto.getId(), dto);
            } else {
                children.add(dto);
            }
        }

        // 先保存父需求
        for (RequirementDTO parent : parentMap.values()) {
            saveRequirement(task, parent, null);
        }

        // 再保存子需求
        for (RequirementDTO child : children) {
            Long parentDbId = getParentDbId(child.getParentId());
            saveRequirement(task, child, parentDbId);
        }
    }

    private void saveRequirement(CollectTask task, RequirementDTO dto, Long parentDbId) {
        try {
            Requirement req = convertToEntity(dto);
            req.setParentId(parentDbId);
            requirementService.saveOrUpdate(req);
            saveRecord(task, dto.getId(), "requirement", CollectRecordStatus.SUCCESS, null);
        } catch (Exception e) {
            saveRecord(task, dto.getId(), "requirement", CollectRecordStatus.FAILED, e.getMessage());
            task.setFailCount(task.getFailCount() + 1);
        }
    }
}
```

## 四、配置管理

### 4.1 采集配置模型

```sql
-- 采集配置表
CREATE TABLE collect_config (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    config_code VARCHAR(100) NOT NULL COMMENT '配置编码',
    config_name VARCHAR(200) NOT NULL COMMENT '配置名称',
    project_id VARCHAR(50) NOT NULL COMMENT '项目ID',
    collect_type VARCHAR(20) NOT NULL COMMENT '采集类型',
    parent_config_id BIGINT COMMENT '父配置ID (继承)',
    config_json TEXT NOT NULL COMMENT '配置内容JSON',
    version VARCHAR(20) NOT NULL COMMENT '版本号',
    status TINYINT DEFAULT 1 COMMENT '状态',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_code_version (config_code, version),
    KEY idx_project (project_id)
) COMMENT '采集配置表';

-- 配置示例
INSERT INTO collect_config (config_code, config_name, project_id, collect_type, config_json, version) VALUES
('testcase-collect-default', '测试用例采集默认配置', '*', 'testcase', '{
  "source": {
    "type": "jira",
    "baseUrl": "https://jira.company.com",
    "auth": {
      "type": "token",
      "tokenKey": "JIRA_TOKEN"
    }
  },
  "filter": {
    "projectKey": "${projectKey}",
    "issueType": "Test Case",
    "status": ["Open", "In Progress", "Done"],
    "dateField": "updated",
    "dateRange": {
      "start": "${startDate}",
      "end": "${endDate}"
    }
  },
  "mapping": {
    "id": "key",
    "title": "summary",
    "description": "description",
    "priority": "priority.name",
    "status": "status.name",
    "createTime": "created",
    "updateTime": "updated",
    "assignee": "assignee.displayName"
  },
  "schedule": {
    "cron": "0 0 2 * * ?",
    "timezone": "Asia/Shanghai"
  },
  "retry": {
    "maxAttempts": 3,
    "backoffMultiplier": 2,
    "initialInterval": 60
  }
}', '1.0');
```

### 4.2 配置服务

```java
@Service
public class CollectConfigService {

    @Autowired
    private CollectConfigRepository configRepo;

    @Autowired
    private NacosConfigService nacosConfigService;

    /**
     * 获取有效配置 (支持继承)
     */
    public CollectConfig getEffectiveConfig(String projectId, String collectType) {
        // 1. 查找项目特定配置
        CollectConfig config = configRepo.findByProjectAndType(projectId, collectType);

        // 2. 如果没有，查找默认配置
        if (config == null) {
            config = configRepo.findByProjectAndType("*", collectType);
        }

        // 3. 处理继承
        if (config != null && config.getParentConfigId() != null) {
            CollectConfig parent = configRepo.findById(config.getParentConfigId()).orElse(null);
            if (parent != null) {
                config = mergeConfig(parent, config);
            }
        }

        return config;
    }

    /**
     * 合并配置 (子配置覆盖父配置)
     */
    private CollectConfig mergeConfig(CollectConfig parent, CollectConfig child) {
        Map<String, Object> parentJson = JsonUtils.parseMap(parent.getConfigJson());
        Map<String, Object> childJson = JsonUtils.parseMap(child.getConfigJson());

        Map<String, Object> merged = deepMerge(parentJson, childJson);

        CollectConfig result = new CollectConfig();
        BeanUtils.copyProperties(child, result);
        result.setConfigJson(JsonUtils.toJson(merged));
        return result;
    }

    /**
     * 发布配置到 Nacos
     */
    public void publishToNacos(Long configId) {
        CollectConfig config = configRepo.findById(configId).orElseThrow();
        String dataId = String.format("collect-config-%s.json", config.getConfigCode());
        nacosConfigService.publishConfig(dataId, "DEFAULT_GROUP", config.getConfigJson());
    }

    /**
     * 配置版本管理
     */
    public void createVersion(Long configId, String newVersion) {
        CollectConfig original = configRepo.findById(configId).orElseThrow();

        CollectConfig newConfig = new CollectConfig();
        BeanUtils.copyProperties(original, newConfig);
        newConfig.setId(null);
        newConfig.setVersion(newVersion);
        newConfig.setCreateTime(LocalDateTime.now());

        configRepo.save(newConfig);
    }
}
```

## 五、监控与可视化

### 5.1 采集监控面板

```java
@RestController
@RequestMapping("/api/collect/monitor")
public class CollectMonitorController {

    @Autowired
    private CollectMonitorService monitorService;

    /**
     * 获取采集任务概览
     */
    @GetMapping("/overview")
    public R<CollectOverviewVO> overview(@RequestParam(required = false) String date) {
        return R.ok(monitorService.getOverview(date));
    }

    /**
     * 获取工作流实例列表
     */
    @GetMapping("/instances")
    public R<PageResult<WorkflowInstanceVO>> instances(WorkflowQueryDTO query) {
        return R.ok(monitorService.getInstances(query));
    }

    /**
     * 获取工作流实例详情
     */
    @GetMapping("/instances/{instanceNo}")
    public R<WorkflowDetailVO> instanceDetail(@PathVariable String instanceNo) {
        return R.ok(monitorService.getInstanceDetail(instanceNo));
    }

    /**
     * 获取步骤执行详情
     */
    @GetMapping("/instances/{instanceNo}/steps")
    public R<List<StepExecutionVO>> steps(@PathVariable String instanceNo) {
        return R.ok(monitorService.getStepExecutions(instanceNo));
    }

    /**
     * 获取实时日志
     */
    @GetMapping("/instances/{instanceNo}/logs")
    public R<List<LogEntry>> logs(@PathVariable String instanceNo,
                                   @RequestParam(defaultValue = "100") Integer limit) {
        return R.ok(monitorService.getLogs(instanceNo, limit));
    }

    /**
     * 获取采集统计
     */
    @GetMapping("/stats")
    public R<CollectStatsVO> stats(@RequestParam String startDate,
                                    @RequestParam String endDate,
                                    @RequestParam(required = false) String collectType) {
        return R.ok(monitorService.getStats(startDate, endDate, collectType));
    }
}

// 监控服务
@Service
public class CollectMonitorService {

    @Autowired
    private LokiClient lokiClient;

    /**
     * 获取概览
     */
    public CollectOverviewVO getOverview(String date) {
        LocalDate targetDate = date != null ? LocalDate.parse(date) : LocalDate.now();

        return CollectOverviewVO.builder()
            .date(targetDate)
            .totalTasks(taskRepo.countByDate(targetDate))
            .runningTasks(taskRepo.countByDateAndStatus(targetDate, CollectStatus.RUNNING))
            .successTasks(taskRepo.countByDateAndStatus(targetDate, CollectStatus.SUCCESS))
            .failedTasks(taskRepo.countByDateAndStatus(targetDate, CollectStatus.FAILED))
            .totalRecords(recordRepo.countByDate(targetDate))
            .successRecords(recordRepo.countByDateAndStatus(targetDate, CollectRecordStatus.SUCCESS))
            .failedRecords(recordRepo.countByDateAndStatus(targetDate, CollectRecordStatus.FAILED))
            .avgDuration(taskRepo.avgDurationByDate(targetDate))
            .build();
    }

    /**
     * 获取实时日志 (从 Loki)
     */
    public List<LogEntry> getLogs(String instanceNo, Integer limit) {
        String query = String.format(
            "{job=\"collect-service\"} |= \"%s\" | json",
            instanceNo
        );
        return lokiClient.query(query, limit);
    }
}
```

### 5.2 可视化组件 (Vue)

```vue
<!-- CollectDashboard.vue -->
<template>
  <div class="collect-dashboard">
    <!-- 概览卡片 -->
    <el-row :gutter="16" class="stat-cards">
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-title">今日任务</div>
          <div class="stat-value">{{ overview.totalTasks }}</div>
          <div class="stat-footer">
            <span class="running">运行中: {{ overview.runningTasks }}</span>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card success">
          <div class="stat-title">成功任务</div>
          <div class="stat-value">{{ overview.successTasks }}</div>
          <div class="stat-footer">
            成功率: {{ successRate }}%
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card danger">
          <div class="stat-title">失败任务</div>
          <div class="stat-value">{{ overview.failedTasks }}</div>
          <div class="stat-footer">
            <el-button link type="primary" @click="showFailedTasks">查看详情</el-button>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-title">平均耗时</div>
          <div class="stat-value">{{ formatDuration(overview.avgDuration) }}</div>
          <div class="stat-footer">
            采集记录: {{ overview.totalRecords }}
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 任务列表 -->
    <el-card class="task-list-card">
      <template #header>
        <div class="card-header">
          <span>采集任务</span>
          <div class="header-actions">
            <el-button type="primary" @click="handleNewTask">
              <el-icon><Plus /></el-icon>
              新建任务
            </el-button>
          </div>
        </div>
      </template>

      <el-table :data="instances" v-loading="loading">
        <el-table-column prop="instanceNo" label="实例编号" width="180">
          <template #default="{ row }">
            <el-link type="primary" @click="showDetail(row)">{{ row.instanceNo }}</el-link>
          </template>
        </el-table-column>
        <el-table-column prop="workflowName" label="工作流" width="150" />
        <el-table-column prop="triggerType" label="触发方式" width="100">
          <template #default="{ row }">
            <el-tag :type="getTriggerTypeColor(row.triggerType)">
              {{ getTriggerTypeLabel(row.triggerType) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="getStatusColor(row.status)">{{ getStatusLabel(row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="progress" label="进度" width="180">
          <template #default="{ row }">
            <el-progress :percentage="row.progress" :status="getProgressStatus(row.status)" />
          </template>
        </el-table-column>
        <el-table-column prop="startTime" label="开始时间" width="180" />
        <el-table-column prop="duration" label="耗时" width="100">
          <template #default="{ row }">
            {{ formatDuration(row.duration) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="showDetail(row)">详情</el-button>
            <el-button link type="primary" @click="showLogs(row)" v-if="row.status === 'running'">日志</el-button>
            <el-button link type="warning" @click="handlePause(row)" v-if="row.status === 'running'">暂停</el-button>
            <el-button link type="success" @click="handleResume(row)" v-if="row.status === 'paused' || row.status === 'failed'">恢复</el-button>
            <el-button link type="danger" @click="handleCancel(row)" v-if="row.status === 'running' || row.status === 'paused'">取消</el-button>
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
        v-model:current-page="page"
        v-model:page-size="pageSize"
        :total="total"
        layout="total, sizes, prev, pager, next"
        @size-change="loadData"
        @current-change="loadData"
      />
    </el-card>

    <!-- 详情抽屉 -->
    <el-drawer v-model="detailVisible" title="任务详情" size="60%">
      <workflow-detail :instance-no="selectedInstanceNo" />
    </el-drawer>

    <!-- 日志弹窗 -->
    <el-dialog v-model="logsVisible" title="实时日志" width="80%">
      <log-viewer :instance-no="selectedInstanceNo" />
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { collectApi } from '@/api/modules/collect'

const overview = ref({})
const instances = ref([])
const loading = ref(false)
const page = ref(1)
const pageSize = ref(10)
const total = ref(0)

const detailVisible = ref(false)
const logsVisible = ref(false)
const selectedInstanceNo = ref('')

const successRate = computed(() => {
  if (overview.value.totalTasks === 0) return 0
  return Math.round(overview.value.successTasks / overview.value.totalTasks * 100)
})

async function loadData() {
  loading.value = true
  try {
    const [overviewData, listData] = await Promise.all([
      collectApi.getOverview(),
      collectApi.getInstances({ page: page.value, pageSize: pageSize.value })
    ])
    overview.value = overviewData
    instances.value = listData.list
    total.value = listData.total
  } finally {
    loading.value = false
  }
}

function showDetail(row) {
  selectedInstanceNo.value = row.instanceNo
  detailVisible.value = true
}

function showLogs(row) {
  selectedInstanceNo.value = row.instanceNo
  logsVisible.value = true
}

async function handleResume(row) {
  await collectApi.resumeWorkflow(row.id)
  loadData()
}

onMounted(loadData)
</script>
```

## 六、API 接口

### 6.1 采集任务 API

```java
@RestController
@RequestMapping("/api/collect")
public class CollectController {

    @Autowired
    private CollectService collectService;

    /**
     * 启动采集任务
     */
    @PostMapping("/start")
    @AuditLog(module = "采集管理", action = "启动采集")
    public R<String> start(@RequestBody @Valid CollectStartDTO dto) {
        String instanceNo = collectService.startCollect(dto);
        return R.ok(instanceNo);
    }

    /**
     * 暂停采集任务
     */
    @PostMapping("/{instanceNo}/pause")
    @AuditLog(module = "采集管理", action = "暂停采集")
    public R<Void> pause(@PathVariable String instanceNo) {
        collectService.pause(instanceNo);
        return R.ok();
    }

    /**
     * 恢复采集任务
     */
    @PostMapping("/{instanceNo}/resume")
    @AuditLog(module = "采集管理", action = "恢复采集")
    public R<Void> resume(@PathVariable String instanceNo) {
        collectService.resume(instanceNo);
        return R.ok();
    }

    /**
     * 取消采集任务
     */
    @PostMapping("/{instanceNo}/cancel")
    @AuditLog(module = "采集管理", action = "取消采集")
    public R<Void> cancel(@PathVariable String instanceNo) {
        collectService.cancel(instanceNo);
        return R.ok();
    }

    /**
     * 重试失败记录
     */
    @PostMapping("/{instanceNo}/retry-failed")
    @AuditLog(module = "采集管理", action = "重试失败记录")
    public R<Void> retryFailed(@PathVariable String instanceNo) {
        collectService.retryFailed(instanceNo);
        return R.ok();
    }

    /**
     * 获取采集配置
     */
    @GetMapping("/configs")
    public R<List<CollectConfigVO>> configs(@RequestParam(required = false) String projectId,
                                             @RequestParam(required = false) String collectType) {
        return R.ok(collectService.getConfigs(projectId, collectType));
    }

    /**
     * 保存采集配置
     */
    @PostMapping("/configs")
    @AuditLog(module = "采集管理", action = "保存配置")
    public R<Long> saveConfig(@RequestBody @Valid CollectConfigDTO dto) {
        return R.ok(collectService.saveConfig(dto));
    }
}
```

## 七、与现有系统集成

### 7.1 XXL-JOB 定时调度

```java
// XXL-JOB 任务处理器
@Component
public class CollectJobHandler {

    @Autowired
    private CollectService collectService;

    /**
     * 测试用例采集任务
     */
    @XxlJob("testCaseCollectJob")
    public void testCaseCollectJob() {
        String param = XxlJobHelper.getJobParam();
        Map<String, Object> params = JsonUtils.parseMap(param);

        String instanceNo = collectService.startCollect(CollectStartDTO.builder()
            .workflowCode("testcase-collection")
            .inputs(params)
            .triggerType("schedule")
            .build());

        XxlJobHelper.log("启动采集任务: {}", instanceNo);

        // 等待完成
        while (true) {
            WorkflowInstance instance = collectService.getInstance(instanceNo);
            if (instance.getStatus() == WorkflowStatus.SUCCESS) {
                XxlJobHelper.handleSuccess("采集完成");
                return;
            } else if (instance.getStatus() == WorkflowStatus.FAILED) {
                XxlJobHelper.handleFail("采集失败: " + instance.getErrorMsg());
                return;
            }
            Thread.sleep(10000);
        }
    }
}
```

### 7.2 消息触发

```java
// RocketMQ 消息监听
@Component
@RocketMQMessageListener(
    topic = "collect-trigger-topic",
    consumerGroup = "collect-trigger-group"
)
public class CollectTriggerListener implements RocketMQListener<CollectTriggerMessage> {

    @Autowired
    private CollectService collectService;

    @Override
    public void onMessage(CollectTriggerMessage message) {
        collectService.startCollect(CollectStartDTO.builder()
            .workflowCode(message.getWorkflowCode())
            .inputs(message.getInputs())
            .triggerType("message")
            .build());
    }
}
```
