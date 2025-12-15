# Spring Boot 4.x 企业级项目底座设计文档

## 一、项目概述

### 1.1 设计目标
- **可开源**：Apache License 2.0 协议，社区友好
- **快速集成**：引入 Starter 即可使用，5 分钟启动业务开发
- **低侵入**：业务代码与底座完全解耦
- **高可扩展**：SPI 机制支持业务定制

### 1.2 技术基线
| 组件 | 版本 | 说明 |
|------|------|------|
| JDK | 21+ | 利用 Virtual Threads、Record、Pattern Matching |
| Spring Boot | 4.x | 基于 Spring Framework 7 |
| Spring Security | 6.x | 新的安全架构 |
| MyBatis-Plus | 4.x | ORM 增强 |

---

## 二、整体架构图

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  业务应用层                                      │
│    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│    │  用户服务    │  │  订单服务    │  │  商品服务    │  │   ...       │          │
│    └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
└───────────┼────────────────┼────────────────┼────────────────┼──────────────────┘
            │                │                │                │
            ▼                ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                             Platform Starters (按需引入)                         │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐  │
│   │   Web    │ │ Security │ │ MyBatis  │ │  Redis   │ │    MQ    │ │  OSS   │  │
│   │ Starter  │ │ Starter  │ │ Starter  │ │ Starter  │ │ Starter  │ │Starter │  │
│   └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘  │
└────────┼────────────┼────────────┼────────────┼────────────┼───────────┼───────┘
         │            │            │            │            │           │
         ▼            ▼            ▼            ▼            ▼           ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               Platform Core                                      │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐              │
│   │  platform-core   │  │  platform-core   │  │  platform-core   │              │
│   │     -common      │  │      -web        │  │    -security     │              │
│   │                  │  │                  │  │                  │              │
│   │ • 异常体系       │  │ • 拦截器         │  │ • JWT Token      │              │
│   │ • 统一响应 R<T>  │  │ • 过滤器         │  │ • 认证授权       │              │
│   │ • 工具类         │  │ • 全局异常处理   │  │ • 数据权限       │              │
│   │ • 上下文         │  │ • 响应包装       │  │ • 加解密         │              │
│   │ • 基础模型       │  │ • API 文档       │  │ • OAuth2         │              │
│   └──────────────────┘  └──────────────────┘  └──────────────────┘              │
│                                                                                  │
│   ┌──────────────────┐  ┌──────────────────────────────────────────────────┐    │
│   │  platform-core   │  │                Platform Plugins                   │    │
│   │     -data        │  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐     │    │
│   │                  │  │  │ Audit  │ │ Tenant │ │Workflow│ │Codegen │     │    │
│   │ • MyBatis 增强   │  │  │  审计  │ │ 多租户 │ │ 工作流 │ │代码生成│     │    │
│   │ • 动态数据源     │  │  └────────┘ └────────┘ └────────┘ └────────┘     │    │
│   │ • 多级缓存       │  └──────────────────────────────────────────────────┘    │
│   │ • 事务增强       │                                                          │
│   └──────────────────┘                                                          │
└─────────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               Platform BOM                                       │
│                            统一依赖版本管理                                       │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 三、项目结构

```
platform-parent/                          # 顶级父 POM
│
├── platform-bom/                         # 依赖版本管理 (BOM)
│   └── pom.xml
│
├── platform-core/                        # 核心基础模块
│   ├── platform-core-common/             # 通用组件
│   │   ├── annotation/                   # 自定义注解
│   │   │   ├── @NoRepeatSubmit           # 防重复提交
│   │   │   ├── @DataScope                # 数据权限
│   │   │   ├── @Log                      # 操作日志
│   │   │   ├── @RateLimit                # 限流
│   │   │   └── @Sensitive                # 数据脱敏
│   │   ├── constant/                     # 常量
│   │   ├── exception/                    # 异常体系
│   │   │   ├── BaseException
│   │   │   ├── BizException
│   │   │   └── ErrorCode
│   │   ├── result/                       # 统一响应
│   │   │   ├── R<T>
│   │   │   ├── PageResult<T>
│   │   │   └── ResultCode
│   │   ├── context/                      # 上下文
│   │   │   ├── UserContext
│   │   │   ├── TenantContext
│   │   │   └── TraceContext
│   │   ├── model/                        # 基础模型
│   │   │   ├── BaseEntity
│   │   │   ├── BaseDTO
│   │   │   └── BaseQuery
│   │   └── util/                         # 工具类
│   │
│   ├── platform-core-web/                # Web 层基础
│   │   ├── config/                       # 配置
│   │   ├── filter/                       # 过滤器
│   │   ├── interceptor/                  # 拦截器
│   │   ├── advice/                       # 全局处理
│   │   └── swagger/                      # API 文档
│   │
│   ├── platform-core-security/           # 安全认证
│   │   ├── token/                        # Token 管理
│   │   ├── authentication/               # 认证
│   │   ├── authorization/                # 授权
│   │   ├── crypto/                       # 加解密
│   │   └── oauth2/                       # OAuth2
│   │
│   └── platform-core-data/               # 数据访问
│       ├── mybatis/                      # MyBatis 增强
│       ├── datasource/                   # 动态数据源
│       ├── transaction/                  # 事务
│       └── cache/                        # 多级缓存
│
├── platform-starters/                    # 自动装配启动器
│   ├── platform-starter-web/             # Web 启动器
│   ├── platform-starter-security/        # 安全启动器
│   ├── platform-starter-mybatis/         # MyBatis 启动器
│   ├── platform-starter-redis/           # Redis 启动器
│   ├── platform-starter-mq/              # 消息队列启动器
│   ├── platform-starter-log/             # 日志启动器
│   ├── platform-starter-job/             # 定时任务启动器
│   └── platform-starter-oss/             # 对象存储启动器
│
├── platform-plugins/                     # 可插拔功能插件
│   ├── platform-plugin-audit/            # 审计日志
│   ├── platform-plugin-tenant/           # 多租户
│   ├── platform-plugin-workflow/         # 工作流
│   └── platform-plugin-codegen/          # 代码生成
│
├── platform-gateway/                     # API 网关 (可选)
├── platform-admin/                       # 管理后台 (可选)
└── platform-samples/                     # 示例项目
    └── platform-sample-basic/
```

---

## 四、核心流程图

### 4.1 请求处理全流程

```
                                    客户端请求
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                              Filter Chain (过滤器链)                            │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│  │  TraceFilter    │───▶│   XssFilter     │───▶│  AuthFilter     │            │
│  │  链路追踪 ID    │    │  XSS 防护       │    │  Token 解析     │            │
│  │  放入 MDC       │    │  参数清洗       │    │  用户上下文     │            │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘            │
└────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                            Interceptor Chain (拦截器链)                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│  │ RateLimitInter. │───▶│  AuthInterceptor│───▶│  LogInterceptor │            │
│  │  接口限流       │    │  权限校验       │    │  请求日志       │            │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘            │
└────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                                  Controller                                     │
│                           参数校验 (@Valid) + 调用 Service                      │
└────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                                   Service                                       │
│                              业务逻辑 + @Transactional                          │
└────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                        MyBatis Interceptor Chain                                │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│  │TenantInterceptor│───▶│DataScopeInter.  │───▶│ AuditInterceptor│            │
│  │  租户条件注入   │    │  数据权限注入   │    │  审计字段填充   │            │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘            │
└────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
                                    ┌─────────┐
                                    │Database │
                                    └─────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                              Response Processing                                │
│  ┌─────────────────────────────┐    ┌─────────────────────────────┐           │
│  │   GlobalResponseAdvice     │    │   GlobalExceptionHandler    │           │
│  │   统一响应包装 R<T>         │    │   异常转换为统一格式        │           │
│  └─────────────────────────────┘    └─────────────────────────────┘           │
└────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
                                    客户端响应
                               { code, msg, data }
```

### 4.2 认证授权流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  登录流程                                        │
│                                                                                  │
│    ┌──────────┐      ┌──────────────┐      ┌──────────────┐      ┌──────────┐  │
│    │ 登录请求 │─────▶│ LoginHandler │─────▶│TokenProvider │─────▶│TokenStore│  │
│    │username  │      │              │      │              │      │          │  │
│    │password  │      │ • 验证码校验 │      │ • 生成 JWT   │      │ • 存储   │  │
│    │captcha   │      │ • 密码校验   │      │ • 设置过期   │      │   Redis  │  │
│    └──────────┘      │ • 多因素认证 │      │              │      │ • 多端   │  │
│                      └──────────────┘      └──────────────┘      │   策略   │  │
│                                                                   └──────────┘  │
│                                                    │                            │
│                                                    ▼                            │
│                                            ┌──────────────┐                     │
│                                            │ 返回 Token   │                     │
│                                            │ + 用户信息   │                     │
│                                            └──────────────┘                     │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  鉴权流程                                        │
│                                                                                  │
│    ┌──────────────┐      ┌───────────────┐      ┌─────────────────┐            │
│    │ 携带 Token   │─────▶│ AuthFilter    │─────▶│ TokenProvider   │            │
│    │ 的业务请求   │      │               │      │                 │            │
│    └──────────────┘      │ 从 Header     │      │ • 解析 Token    │            │
│                          │ 提取 Token    │      │ • 验证签名      │            │
│                          └───────────────┘      │ • 检查过期      │            │
│                                                 └────────┬────────┘            │
│                                                          │                     │
│                                                          ▼                     │
│                          ┌───────────────┐      ┌─────────────────┐            │
│                          │ UserContext   │◀─────│ 加载用户信息    │            │
│                          │ 设置当前用户  │      │ 权限、角色      │            │
│                          └───────┬───────┘      └─────────────────┘            │
│                                  │                                             │
│                                  ▼                                             │
│    ┌──────────────────────────────────────────────────────────────────────┐   │
│    │                    @RequiresPermission("user:list")                   │   │
│    │                                     │                                 │   │
│    │                                     ▼                                 │   │
│    │  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐      │   │
│    │  │PermissionAspect│───▶│PermissionServ.│───▶│   有权限？      │      │   │
│    │  │    AOP 拦截    │    │ 权限校验逻辑   │    │ Y: 继续执行    │      │   │
│    │  └────────────────┘    └────────────────┘    │ N: 抛出异常    │      │   │
│    │                                              └────────────────┘      │   │
│    └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 数据权限流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                数据权限处理流程                                   │
│                                                                                  │
│   @DataScope(deptAlias = "d", userAlias = "u")                                  │
│   public List<Order> selectOrders(OrderQuery query) { ... }                     │
│                          │                                                       │
│                          ▼                                                       │
│   ┌────────────────────────────────────────────────────────────────────────┐    │
│   │                        DataScopeAspect (AOP)                            │    │
│   │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐      │    │
│   │  │ 获取当前用户     │─▶│ 获取数据权限类型 │─▶│ 构建权限 SQL     │      │    │
│   │  │ UserContext.get()│  │ DATA_SCOPE_ALL   │  │ 放入 ThreadLocal │      │    │
│   │  │                  │  │ DATA_SCOPE_DEPT  │  │                  │      │    │
│   │  │                  │  │ DATA_SCOPE_SELF  │  │                  │      │    │
│   │  └──────────────────┘  └──────────────────┘  └──────────────────┘      │    │
│   └────────────────────────────────────────────────────────────────────────┘    │
│                          │                                                       │
│                          ▼                                                       │
│   ┌────────────────────────────────────────────────────────────────────────┐    │
│   │                  DataScopeInterceptor (MyBatis)                         │    │
│   │                                                                         │    │
│   │   原始 SQL:                                                             │    │
│   │   SELECT * FROM orders o LEFT JOIN dept d ON o.dept_id = d.id          │    │
│   │                          │                                              │    │
│   │                          ▼                                              │    │
│   │   权限类型判断:                                                         │    │
│   │   ┌──────────────────────────────────────────────────────────────┐     │    │
│   │   │ DATA_SCOPE_ALL   → 不追加条件                                 │     │    │
│   │   │ DATA_SCOPE_DEPT  → AND d.dept_id IN (用户部门及子部门)        │     │    │
│   │   │ DATA_SCOPE_SELF  → AND o.create_by = '当前用户'               │     │    │
│   │   │ DATA_SCOPE_CUSTOM→ AND d.dept_id IN (自定义部门列表)          │     │    │
│   │   └──────────────────────────────────────────────────────────────┘     │    │
│   │                          │                                              │    │
│   │                          ▼                                              │    │
│   │   拼接后 SQL:                                                           │    │
│   │   SELECT * FROM orders o LEFT JOIN dept d ON o.dept_id = d.id          │    │
│   │   WHERE d.dept_id IN (100, 101, 102) OR o.create_by = 'admin'          │    │
│   │                                                                         │    │
│   └────────────────────────────────────────────────────────────────────────┘    │
│                          │                                                       │
│                          ▼                                                       │
│                     执行 SQL，返回过滤后的数据                                    │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 4.4 多租户数据隔离流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               多租户数据隔离流程                                  │
│                                                                                  │
│   ┌──────────────────────────────────────────────────────────────────────────┐  │
│   │                           租户识别                                        │  │
│   │   ┌────────────┐    ┌────────────┐    ┌────────────┐    ┌────────────┐   │  │
│   │   │   Header   │    │  Domain    │    │   Token    │    │   Path     │   │  │
│   │   │ X-Tenant-Id│ OR │ xxx.com    │ OR │ 解析租户ID │ OR │ /t/{id}/.. │   │  │
│   │   └─────┬──────┘    └─────┬──────┘    └─────┬──────┘    └─────┬──────┘   │  │
│   │         └─────────────────┴─────────────────┴─────────────────┘          │  │
│   │                                     │                                     │  │
│   │                                     ▼                                     │  │
│   │                          ┌──────────────────┐                             │  │
│   │                          │  TenantContext   │                             │  │
│   │                          │  存储租户 ID     │                             │  │
│   │                          └──────────────────┘                             │  │
│   └──────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                           │
│                                     ▼                                           │
│   ┌──────────────────────────────────────────────────────────────────────────┐  │
│   │                    隔离策略 (可配置)                                       │  │
│   │                                                                           │  │
│   │   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │  │
│   │   │  行级隔离 (ROW) │  │ Schema 隔离     │  │ 数据库隔离       │          │  │
│   │   │                 │  │                 │  │                 │          │  │
│   │   │ WHERE tenant_id │  │ 切换 Schema     │  │ 切换数据源      │          │  │
│   │   │ = 当前租户      │  │ tenant_001      │  │ ds_tenant_001   │          │  │
│   │   │                 │  │ tenant_002      │  │ ds_tenant_002   │          │  │
│   │   └─────────────────┘  └─────────────────┘  └─────────────────┘          │  │
│   │          ▲                    ▲                    ▲                      │  │
│   │          │                    │                    │                      │  │
│   │          └────────────────────┼────────────────────┘                      │  │
│   │                               │                                           │  │
│   │                    TenantInterceptor (MyBatis)                            │  │
│   │                    自动注入租户条件                                        │  │
│   └──────────────────────────────────────────────────────────────────────────┘  │
│                                     │                                           │
│                                     ▼                                           │
│   ┌──────────────────────────────────────────────────────────────────────────┐  │
│   │                        租户忽略表配置                                      │  │
│   │   platform.tenant.ignore-tables: sys_config, sys_dict                    │  │
│   │   → 这些表的查询不会追加租户条件                                          │  │
│   └──────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 五、自动装配机制

### 5.1 Starter 结构

```
platform-starter-web/
├── src/main/java/com/platform/starter/web/
│   ├── PlatformWebAutoConfiguration.java     # 自动配置主类
│   ├── PlatformWebProperties.java            # 配置属性绑定
│   ├── condition/
│   │   └── ConditionalOnPlatformWeb.java     # 条件注解
│   └── customizer/
│       └── WebMvcRegistrationsCustomizer.java
├── src/main/resources/
│   ├── META-INF/spring/
│   │   └── org.springframework.boot.autoconfigure.AutoConfiguration.imports
│   └── platform-web-default.yml              # 默认配置
└── pom.xml
```

### 5.2 自动装配流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              自动装配流程                                        │
│                                                                                  │
│   ┌──────────────────┐                                                          │
│   │ 业务项目引入     │                                                          │
│   │ starter 依赖     │                                                          │
│   └────────┬─────────┘                                                          │
│            │                                                                     │
│            ▼                                                                     │
│   ┌──────────────────────────────────────────────────────────────────────────┐  │
│   │ Spring Boot 启动                                                          │  │
│   │                                                                           │  │
│   │  1. 扫描 META-INF/spring/...AutoConfiguration.imports                    │  │
│   │                    │                                                      │  │
│   │                    ▼                                                      │  │
│   │  2. 加载 PlatformWebAutoConfiguration                                    │  │
│   │                    │                                                      │  │
│   │                    ▼                                                      │  │
│   │  3. 条件判断                                                              │  │
│   │     ┌────────────────────────────────────────────────────────────────┐   │  │
│   │     │ @ConditionalOnClass(DispatcherServlet.class)        ✓ 存在     │   │  │
│   │     │ @ConditionalOnProperty("platform.web.enabled")      ✓ true     │   │  │
│   │     │ @ConditionalOnMissingBean(GlobalExceptionHandler)   ✓ 不存在   │   │  │
│   │     └────────────────────────────────────────────────────────────────┘   │  │
│   │                    │                                                      │  │
│   │                    ▼                                                      │  │
│   │  4. 加载配置                                                              │  │
│   │     优先级: application.yml > platform-web-default.yml > 硬编码默认值    │  │
│   │                    │                                                      │  │
│   │                    ▼                                                      │  │
│   │  5. 注册 Bean                                                             │  │
│   │     • GlobalExceptionHandler                                             │  │
│   │     • GlobalResponseAdvice                                               │  │
│   │     • TraceFilter                                                        │  │
│   │     • ...                                                                │  │
│   │                    │                                                      │  │
│   │                    ▼                                                      │  │
│   │  6. 业务直接使用                                                          │  │
│   └──────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 六、业务快速集成指南

### 6.1 Step 1: 引入依赖

```xml
<!-- 业务项目 pom.xml -->
<parent>
    <groupId>com.platform</groupId>
    <artifactId>platform-bom</artifactId>
    <version>1.0.0</version>
    <relativePath/>
</parent>

<dependencies>
    <!-- 必选: Web 启动器 -->
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-starter-web</artifactId>
    </dependency>

    <!-- 必选: MyBatis 启动器 -->
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-starter-mybatis</artifactId>
    </dependency>

    <!-- 可选: 安全启动器 -->
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-starter-security</artifactId>
    </dependency>

    <!-- 可选: Redis 启动器 -->
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-starter-redis</artifactId>
    </dependency>

    <!-- 可选: 多租户插件 -->
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-plugin-tenant</artifactId>
    </dependency>
</dependencies>
```

### 6.2 Step 2: 最小配置

```yaml
# application.yml
platform:
  web:
    enabled: true
    cors:
      allowed-origins: "*"
  security:
    enabled: true
    token:
      secret: ${JWT_SECRET:your-256-bit-secret-key-here}
      expire: 7200
      refresh-expire: 604800
    ignore-urls:
      - /api/auth/login
      - /api/auth/register
      - /doc.html
      - /swagger-resources/**
  mybatis:
    enabled: true
    mapper-locations: classpath*:mapper/**/*.xml
  tenant:
    enabled: false  # 按需开启多租户

spring:
  datasource:
    url: jdbc:mysql://localhost:3306/demo?useSSL=false&serverTimezone=Asia/Shanghai
    username: root
    password: ${DB_PASSWORD}
    driver-class-name: com.mysql.cj.jdbc.Driver
  data:
    redis:
      host: localhost
      port: 6379
      password: ${REDIS_PASSWORD:}
```

### 6.3 Step 3: 开始开发

```java
// 开箱即用，专注业务逻辑

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping
    @RequiresPermission("system:user:list")
    @Log(title = "用户管理", businessType = BusinessType.QUERY)
    public R<PageResult<UserVO>> list(UserQuery query) {
        return R.ok(userService.page(query));
    }

    @PostMapping
    @RequiresPermission("system:user:add")
    @Log(title = "用户管理", businessType = BusinessType.INSERT)
    @NoRepeatSubmit(interval = 5000)
    public R<Long> create(@Valid @RequestBody UserCreateDTO dto) {
        return R.ok(userService.create(dto));
    }

    @PutMapping("/{id}")
    @RequiresPermission("system:user:edit")
    @Log(title = "用户管理", businessType = BusinessType.UPDATE)
    public R<Void> update(@PathVariable Long id, @Valid @RequestBody UserUpdateDTO dto) {
        userService.update(id, dto);
        return R.ok();
    }

    @DeleteMapping("/{id}")
    @RequiresPermission("system:user:delete")
    @Log(title = "用户管理", businessType = BusinessType.DELETE)
    public R<Void> delete(@PathVariable Long id) {
        userService.delete(id);
        return R.ok();
    }
}
```

```java
// Service 层 - 数据权限自动生效

@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserMapper userMapper;

    @Override
    @DataScope(deptAlias = "d")  // 自动追加数据权限条件
    public PageResult<UserVO> page(UserQuery query) {
        Page<UserVO> page = userMapper.selectUserPage(
            new Page<>(query.getPageNum(), query.getPageSize()),
            query
        );
        return PageResult.of(page);
    }
}
```

---

## 七、SPI 扩展机制

### 7.1 可扩展点列表

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               SPI 扩展点                                         │
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ 认证扩展                                                                 │   │
│   │ • AuthenticationProvider    - 自定义认证方式 (短信、OAuth、LDAP)        │   │
│   │ • UserDetailsService        - 自定义用户加载逻辑                        │   │
│   │ • TokenProvider             - 自定义 Token 生成策略                     │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ 权限扩展                                                                 │   │
│   │ • PermissionEvaluator       - 自定义权限校验逻辑                        │   │
│   │ • DataScopeHandler          - 自定义数据权限规则                        │   │
│   │ • RoleHierarchy             - 自定义角色继承关系                        │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ 日志扩展                                                                 │   │
│   │ • OperationLogHandler       - 自定义操作日志存储                        │   │
│   │ • AuditLogHandler           - 自定义审计日志处理                        │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ 异常扩展                                                                 │   │
│   │ • ExceptionTranslator       - 自定义异常转换                            │   │
│   │ • ErrorCodeResolver         - 自定义错误码解析                          │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ ID 生成扩展                                                              │   │
│   │ • IdGenerator               - 自定义 ID 生成策略 (雪花、UUID、Segment)  │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ 租户扩展                                                                 │   │
│   │ • TenantResolver            - 自定义租户识别方式                        │   │
│   │ • TenantDataSourceProvider  - 自定义租户数据源                          │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 扩展示例

```java
// 示例: 自定义短信登录认证
@Component
public class SmsAuthenticationProvider implements AuthenticationProvider {

    @Override
    public Authentication authenticate(Authentication authentication) {
        SmsAuthenticationToken token = (SmsAuthenticationToken) authentication;
        String mobile = token.getMobile();
        String code = token.getCode();

        // 验证短信验证码
        if (!smsService.verify(mobile, code)) {
            throw new AuthException("验证码错误");
        }

        // 加载用户
        UserDetails user = userService.loadUserByMobile(mobile);
        return new UsernamePasswordAuthenticationToken(user, null, user.getAuthorities());
    }

    @Override
    public boolean supports(Class<?> authentication) {
        return SmsAuthenticationToken.class.isAssignableFrom(authentication);
    }
}
```

```java
// 示例: 自定义数据权限处理
@Component
public class CustomDataScopeHandler implements DataScopeHandler {

    @Override
    public String getScopeSql(DataScopeType type, String alias, LoginUser user) {
        return switch (type) {
            case ALL -> "";
            case DEPT -> String.format("%s.dept_id IN (%s)", alias,
                String.join(",", user.getDeptIds()));
            case SELF -> String.format("%s.create_by = '%s'", alias, user.getUsername());
            case CUSTOM -> buildCustomScope(alias, user);
        };
    }
}
```

---

## 八、技术选型详情

| 分类 | 技术 | 版本 | 说明 |
|------|------|------|------|
| **基础框架** | Spring Boot | 4.x | 基于 Spring Framework 7 |
| | Spring Framework | 7.x | AOT 编译支持、Virtual Threads |
| **JDK** | OpenJDK | 21+ LTS | Virtual Threads, Pattern Matching, Records |
| **构建** | Maven | 3.9+ | 依赖管理 |
| | Gradle | 8.x | 可选构建工具 |
| **安全** | Spring Security | 6.x | 新的 SecurityFilterChain 配置 |
| | JWT | jjwt 0.12+ | Token 生成与验证 |
| **ORM** | MyBatis-Plus | 4.x | 增强 CRUD |
| | Dynamic Datasource | 4.x | 动态数据源 |
| **缓存** | Redis | 7.x | 分布式缓存 |
| | Caffeine | 3.x | 本地缓存 |
| | Spring Cache | - | 缓存抽象 |
| **数据库** | MySQL | 8.x | 主数据库 |
| | PostgreSQL | 15+ | 可选 |
| | HikariCP | 5.x | 连接池 |
| **API 文档** | SpringDoc OpenAPI | 2.x | Swagger 替代 |
| **校验** | Hibernate Validator | 8.x | 参数校验 |
| **序列化** | Jackson | 2.17+ | JSON 处理 |
| **日志** | SLF4J | 2.x | 日志门面 |
| | Logback | 1.5+ | 日志实现 |
| **监控** | Micrometer | 1.13+ | 指标采集 |
| | Prometheus | - | 指标存储 |
| | Micrometer Tracing | 1.3+ | 链路追踪 |
| **消息队列** | RabbitMQ | 3.x | 消息队列 (可选) |
| | Apache Kafka | 3.x | 消息队列 (可选) |
| **定时任务** | XXL-Job | 2.x | 分布式定时任务 |

---

## 九、开源协议

**Apache License 2.0**

- 允许商业使用
- 允许修改和分发
- 必须保留版权声明
- 不提供任何担保

---

## 十、路线图

### Phase 1: 核心基础 (v1.0)
- [x] platform-bom 版本管理
- [x] platform-core-common 基础组件
- [x] platform-core-web Web 层
- [x] platform-starter-web 自动装配
- [x] platform-starter-mybatis 数据层

### Phase 2: 安全增强 (v1.1)
- [ ] platform-core-security 安全认证
- [ ] platform-starter-security 安全启动器
- [ ] platform-starter-redis 缓存启动器
- [ ] OAuth2 支持

### Phase 3: 企业特性 (v1.2)
- [ ] platform-plugin-tenant 多租户
- [ ] platform-plugin-audit 审计日志
- [ ] platform-plugin-workflow 工作流
- [ ] platform-starter-mq 消息队列

### Phase 4: 生态完善 (v2.0)
- [ ] platform-gateway API 网关
- [ ] platform-admin 管理后台
- [ ] platform-plugin-codegen 代码生成
- [ ] 完整文档和示例
