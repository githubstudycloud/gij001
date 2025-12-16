# Spring Boot 4.x 企业级项目底座设计文档

## 一、项目概述

### 1.1 设计目标
- **可开源**：Apache License 2.0 协议，社区友好
- **快速集成**：引入 Starter 即可使用，5 分钟启动业务开发
- **低侵入**：业务代码与底座完全解耦
- **高可扩展**：SPI 机制支持业务定制
- **双模式支持**：单体开发调试，微服务生产部署

### 1.2 技术基线
| 组件 | 版本 | 说明 |
|------|------|------|
| JDK | 21+ | 利用 Virtual Threads、Record、Pattern Matching |
| Spring Boot | 4.x | 基于 Spring Framework 7 |
| Spring Cloud | 2025.x | 微服务支持 (可选) |
| MyBatis-Plus | 4.x | ORM 增强 |

---

## 二、开源项目调研对比

> 参考资料来源：[RuoYi-Vue-Pro](https://doc.iocoder.cn/)、[JeecgBoot](https://help.jeecg.com/)、[Pig](https://gitee.com/log4j/pig)、[SpringBlade](https://github.com/chillzhuang/SpringBlade)、[ContiNew Admin](https://github.com/continew-org/continew-admin)、[Sa-Token](https://sa-token.cc/)

### 2.1 主流框架对比

| 项目 | 架构模式 | 权限框架 | 多租户 | 代码生成 | 特色亮点 |
|------|---------|---------|--------|---------|---------|
| **RuoYi-Vue-Pro** | 单体模块化 | Sa-Token | ✓ SaaS | ✓ 低代码 | 12+ 业务模块、模块化单体 |
| **JeecgBoot** | 单体/微服务 | Shiro/Security | ✓ | 低代码 | AI 低代码、工作流、Deepseek |
| **Pig** | 微服务 | Spring Auth Server | - | ✓ | OAuth2 生产级实践、6 年稳定 |
| **SpringBlade** | 单体/微服务 | 自研 Secure | ✓ SaaS | ✓ | 阿里规范、多租户灵活组合 |
| **ContiNew Admin** | 单体 | Sa-Token | ✓ | ✓ | 代码规范最佳、CRUD 套件 |

### 2.2 吸收的最佳实践

| 最佳实践 | 来源项目 | 设计要点 |
|---------|---------|---------|
| API 与实现分离 | Pig/SpringBlade | `xxx-api` + `xxx-biz` 分离，微服务调用只需引入 api |
| 四层模块架构 | RuoYi-Vue-Pro | dependencies → framework → module → server |
| CRUD 套件 | ContiNew Admin | BaseService 几分钟生成完整 CRUD API |
| 数据库版本管理 | ContiNew Admin | Liquibase 管理数据库变更 |
| JetCache 多级缓存 | ContiNew Admin | 注解式缓存、本地 + Redis 两级 |
| 字典翻译注解 | RuoYi/ContiNew | @DictFormat 自动翻译 |
| 数据填充 | ContiNew Admin | Crane4j 自动填充关联字段 |
| 文件存储抽象 | ContiNew Admin | X File Storage 统一适配多种存储 |
| 单体/微服务双模式 | Pig/SpringBlade | Maven Profile 切换部署模式 |
| Visual 可视化层 | Pig | 监控、代码生成、报表独立模块 |

---

## 三、整体架构图

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
│                          Platform Module (业务模块层)                            │
│   ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐       │
│   │ platform-module    │  │ platform-module    │  │ platform-module    │       │
│   │    -system         │  │    -infra          │  │    -xxx            │       │
│   │  ┌──────┬──────┐   │  │  ┌──────┬──────┐   │  │  ┌──────┬──────┐   │       │
│   │  │ api  │ biz  │   │  │  │ api  │ biz  │   │  │  │ api  │ biz  │   │       │
│   │  └──────┴──────┘   │  │  └──────┴──────┘   │  │  └──────┴──────┘   │       │
│   └────────────────────┘  └────────────────────┘  └────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────────┘
            │                │                │                │
            ▼                ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                       Platform Framework (框架层)                                │
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                    platform-spring-boot-starter-xxx                      │   │
│   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐     │   │
│   │  │  web   │ │security│ │mybatis │ │ redis  │ │  log   │ │  oss   │ ... │   │
│   │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘     │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                         platform-common-xxx                              │   │
│   │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐        │   │
│   │  │ core │ │ web  │ │secur.│ │mybat.│ │redis │ │ log  │ │ oss  │ ...    │   │
│   │  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘        │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                       Platform Dependencies (BOM)                                │
│                          统一依赖版本管理                                         │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                          Platform Visual (可视化层)                              │
│   ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                   │
│   │    monitor     │  │    codegen     │  │    report      │                   │
│   │   服务监控      │  │   代码生成      │  │   报表中心      │                   │
│   └────────────────┘  └────────────────┘  └────────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                        部署模式切换 (Maven Profile)                              │
│   ┌──────────────────────────────┐  ┌──────────────────────────────┐           │
│   │     -P single (单体模式)      │  │     -P cloud (微服务模式)     │           │
│   │  ┌──────────────────────┐    │  │  ┌────────┐  ┌────────────┐  │           │
│   │  │   platform-server    │    │  │  │gateway │  │  register  │  │           │
│   │  │   聚合所有 biz 模块   │    │  │  │  网关  │  │ Nacos 注册 │  │           │
│   │  └──────────────────────┘    │  │  └────────┘  └────────────┘  │           │
│   └──────────────────────────────┘  └──────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 四、优化后的项目结构

```
platform-parent/                              # 顶级父 POM
│
├── platform-dependencies/                    # BOM 依赖版本管理 (参考 RuoYi)
│   └── pom.xml
│
├── platform-framework/                       # 框架层 - 技术组件
│   │
│   ├── platform-common/                      # 公共模块集合
│   │   ├── platform-common-bom/              # 内部模块 BOM
│   │   ├── platform-common-core/             # 核心基础
│   │   │   ├── annotation/                   # 自定义注解
│   │   │   │   ├── @RepeatSubmit            # 防重复提交 (增强版)
│   │   │   │   ├── @DataScope               # 数据权限
│   │   │   │   ├── @Log                     # 操作日志
│   │   │   │   ├── @RateLimit               # 限流
│   │   │   │   ├── @Sensitive               # 数据脱敏
│   │   │   │   ├── @DictFormat              # 字典翻译 ✨新增
│   │   │   │   └── @DataFill                # 数据填充 ✨新增
│   │   │   ├── constant/                    # 常量定义
│   │   │   ├── exception/                   # 异常体系
│   │   │   ├── result/                      # 统一响应
│   │   │   ├── context/                     # 上下文
│   │   │   ├── model/                       # 基础模型
│   │   │   │   ├── BaseEntity               # 实体基类
│   │   │   │   ├── BaseDO                   # DO 基类 ✨新增
│   │   │   │   ├── BaseDTO                  # DTO 基类
│   │   │   │   ├── BaseVO                   # VO 基类 ✨新增
│   │   │   │   └── BaseQuery                # 查询基类
│   │   │   ├── service/                     # 服务基类 ✨新增
│   │   │   │   ├── BaseService<E,ID,Q,C,U>  # CRUD 服务接口
│   │   │   │   └── BaseServiceImpl          # CRUD 服务实现
│   │   │   └── util/                        # 工具类
│   │   │
│   │   ├── platform-common-web/             # Web 层
│   │   │   ├── config/                      # 配置
│   │   │   ├── filter/                      # 过滤器
│   │   │   ├── interceptor/                 # 拦截器
│   │   │   ├── advice/                      # 全局处理
│   │   │   └── xss/                         # XSS 防护
│   │   │
│   │   ├── platform-common-security/        # 安全认证 (Sa-Token)
│   │   │   ├── token/                       # Token 管理
│   │   │   ├── permission/                  # 权限校验
│   │   │   ├── datascope/                   # 数据权限
│   │   │   └── crypto/                      # 加解密
│   │   │
│   │   ├── platform-common-mybatis/         # MyBatis 增强
│   │   │   ├── core/                        # 核心配置
│   │   │   ├── interceptor/                 # 拦截器
│   │   │   ├── handler/                     # 类型处理器
│   │   │   └── injector/                    # SQL 注入器
│   │   │
│   │   ├── platform-common-redis/           # Redis 缓存
│   │   │   ├── config/                      # 配置
│   │   │   ├── cache/                       # JetCache 多级缓存 ✨新增
│   │   │   └── util/                        # 工具类
│   │   │
│   │   ├── platform-common-datasource/      # 动态数据源
│   │   ├── platform-common-tenant/          # 多租户
│   │   ├── platform-common-log/             # 日志组件
│   │   ├── platform-common-oss/             # 文件存储 (X File Storage)
│   │   ├── platform-common-excel/           # Excel (FastExcel) ✨新增
│   │   ├── platform-common-job/             # 定时任务
│   │   ├── platform-common-mq/              # 消息队列
│   │   ├── platform-common-doc/             # API 文档 (Knife4j)
│   │   └── platform-common-liquibase/       # 数据库变更 ✨新增
│   │
│   └── platform-spring-boot-starter/        # 自动装配启动器
│       ├── platform-spring-boot-starter-web/
│       ├── platform-spring-boot-starter-security/
│       ├── platform-spring-boot-starter-mybatis/
│       ├── platform-spring-boot-starter-redis/
│       ├── platform-spring-boot-starter-oss/
│       ├── platform-spring-boot-starter-excel/
│       ├── platform-spring-boot-starter-job/
│       ├── platform-spring-boot-starter-mq/
│       └── platform-spring-boot-starter-tenant/
│
├── platform-module/                          # 业务模块层 (参考 RuoYi)
│   │
│   ├── platform-module-system/               # 系统管理模块
│   │   ├── platform-module-system-api/       # API 定义 (DTO/VO/Feign)
│   │   │   ├── dto/
│   │   │   ├── vo/
│   │   │   ├── enums/
│   │   │   └── feign/                        # Feign Client (微服务用)
│   │   └── platform-module-system-biz/       # 业务实现
│   │       ├── controller/
│   │       │   ├── admin/                    # 管理端 API
│   │       │   └── app/                      # 用户端 API
│   │       ├── service/
│   │       ├── mapper/
│   │       ├── convert/                      # 对象转换 (MapStruct)
│   │       └── dal/                          # 数据访问层
│   │           ├── dataobject/               # DO 对象
│   │           └── redis/                    # Redis DAO
│   │
│   ├── platform-module-infra/                # 基础设施模块
│   │   ├── platform-module-infra-api/
│   │   └── platform-module-infra-biz/
│   │       ├── file/                         # 文件管理
│   │       ├── config/                       # 参数配置
│   │       ├── dict/                         # 数据字典
│   │       ├── job/                          # 定时任务
│   │       └── logger/                       # 日志管理
│   │
│   └── platform-module-xxx/                  # 其他业务模块 (按需扩展)
│
├── platform-server/                          # 单体启动模块 (聚合所有 biz)
│   └── src/main/java/
│       └── PlatformServerApplication.java
│
├── platform-gateway/                         # 微服务网关 (可选)
├── platform-register/                        # 注册中心 (可选, 内置 Nacos)
│
└── platform-visual/                          # 可视化模块 (参考 Pig)
    ├── platform-visual-monitor/              # 服务监控 (Spring Boot Admin)
    ├── platform-visual-codegen/              # 代码生成器
    └── platform-visual-report/               # 报表中心
```

---

## 五、核心流程图

### 5.1 请求处理全流程

```
                                    客户端请求
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                              Filter Chain (过滤器链)                            │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│  │  TraceFilter    │───▶│   XssFilter     │───▶│  SaTokenFilter  │            │
│  │  链路追踪 ID    │    │  XSS 防护       │    │  Sa-Token 认证  │            │
│  │  放入 MDC       │    │  参数清洗       │    │  用户上下文     │            │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘            │
└────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                            Interceptor Chain (拦截器链)                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│  │ RateLimitInter. │───▶│ RepeatSubmitInt.│───▶│  LogInterceptor │            │
│  │  接口限流       │    │  防重复提交     │    │  请求日志       │            │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘            │
└────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                                  Controller                                     │
│            参数校验 (@Valid) + @SaCheckPermission 权限校验                      │
└────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                                   Service                                       │
│                  BaseService CRUD 套件 + @Transactional                        │
└────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                        MyBatis Interceptor Chain                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌───────────┐ │
│  │TenantInterceptor│─▶│DataScopeInter.  │─▶│ AuditInterceptor│─▶│EncryptInt.│ │
│  │  租户条件注入   │  │  数据权限注入   │  │  审计字段填充   │  │字段加解密 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └───────────┘ │
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
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
│  │ DictTranslate   │─▶│ DataFillAdvice  │─▶│ SensitiveAdvice │                │
│  │ 字典翻译        │  │ 数据填充        │  │ 数据脱敏        │                │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                │
│                                      │                                         │
│                                      ▼                                         │
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

### 5.2 CRUD 套件流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CRUD 套件使用流程                                   │
│                                                                                  │
│   1. 定义 Service 接口，继承 BaseService                                        │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ public interface UserService                                             │   │
│   │     extends BaseService<User, Long, UserQuery, UserCreateDTO, UserDTO> { │   │
│   │     // 自动拥有: create, update, delete, get, page, list, export         │   │
│   │     // 只需添加自定义业务方法                                             │   │
│   │ }                                                                        │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│   2. 实现类继承 BaseServiceImpl                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ @Service                                                                 │   │
│   │ public class UserServiceImpl                                             │   │
│   │     extends BaseServiceImpl<UserMapper, User, Long, UserQuery,           │   │
│   │                             UserCreateDTO, UserDTO>                      │   │
│   │     implements UserService {                                             │   │
│   │     // CRUD 已自动实现，专注业务逻辑                                      │   │
│   │ }                                                                        │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│   3. Controller 直接使用                                                        │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ @GetMapping                                                              │   │
│   │ public R<PageResult<UserVO>> page(UserQuery query) {                     │   │
│   │     return R.ok(userService.page(query));  // 开箱即用                   │   │
│   │ }                                                                        │   │
│   │                                                                          │   │
│   │ @GetMapping("/export")                                                   │   │
│   │ public void export(UserQuery query, HttpServletResponse response) {      │   │
│   │     userService.export(query, response);   // 自动 Excel 导出           │   │
│   │ }                                                                        │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 数据权限 & 多租户流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            数据权限 + 多租户 联合处理                            │
│                                                                                  │
│   @DataScope(deptAlias = "d")                                                   │
│   public List<Order> selectOrders() { ... }                                     │
│                          │                                                       │
│                          ▼                                                       │
│   ┌────────────────────────────────────────────────────────────────────────┐    │
│   │                     租户 + 数据权限 拦截器链                             │    │
│   │                                                                         │    │
│   │   原始 SQL:                                                             │    │
│   │   SELECT * FROM orders o LEFT JOIN dept d ON o.dept_id = d.id          │    │
│   │                          │                                              │    │
│   │                          ▼                                              │    │
│   │   Step 1: TenantInterceptor (租户隔离)                                  │    │
│   │   SELECT * FROM orders o LEFT JOIN dept d ON o.dept_id = d.id          │    │
│   │   WHERE o.tenant_id = 1001                                              │    │
│   │                          │                                              │    │
│   │                          ▼                                              │    │
│   │   Step 2: DataScopeInterceptor (数据权限)                               │    │
│   │   SELECT * FROM orders o LEFT JOIN dept d ON o.dept_id = d.id          │    │
│   │   WHERE o.tenant_id = 1001                                              │    │
│   │   AND (d.dept_id IN (100, 101) OR o.create_by = 'admin')               │    │
│   │                                                                         │    │
│   └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│   多租户隔离策略 (可配置):                                                       │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
│   │  行级隔离 (ROW) │  │ Schema 隔离     │  │ 数据库隔离       │                │
│   │  tenant_id 字段 │  │ 动态切换 Schema │  │ 动态切换数据源   │                │
│   │  适合中小租户   │  │  适合中型租户   │  │  适合大型租户    │                │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘                │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 六、功能注解体系

### 6.1 核心注解一览

```java
// ==================== 权限控制 ====================
@SaCheckPermission("system:user:list")     // Sa-Token 权限校验
@SaCheckRole("admin")                       // Sa-Token 角色校验
@DataScope(deptAlias = "d")                // 数据权限

// ==================== 操作日志 ====================
@Log(module = "用户管理",
     operationType = OperationType.INSERT,
     saveRequestData = true,
     saveResponseData = false)

// ==================== 接口防护 ====================
@RateLimit(key = "login", count = 5, time = 60,
           message = "登录过于频繁，请稍后再试")
@RepeatSubmit(interval = 5000,
              lockType = LockType.GLOBAL)   // Redis 分布式锁

// ==================== 数据处理 ====================
@DictFormat("sys_user_status")             // 字典翻译 (0→正常, 1→停用)
@Sensitive(strategy = SensitiveStrategy.PHONE)  // 脱敏 (138****8888)
@DataFill(container = "user",
          props = @Prop(ref = "userName")) // 数据填充

// ==================== 缓存控制 ====================
@Cached(name = "user:", key = "#id",
        expire = 1, timeUnit = TimeUnit.HOURS)  // JetCache 缓存
@CacheRefresh(refresh = 30)                     // 自动刷新

// ==================== 数据库 ====================
@DS("slave")                               // 动态数据源切换
@DSTransactional                           // 跨数据源事务
```

### 6.2 使用示例

```java
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping
    @SaCheckPermission("system:user:list")
    @Log(module = "用户管理", operationType = OperationType.QUERY)
    public R<PageResult<UserVO>> page(UserQuery query) {
        return R.ok(userService.page(query));
    }

    @PostMapping
    @SaCheckPermission("system:user:add")
    @Log(module = "用户管理", operationType = OperationType.INSERT)
    @RepeatSubmit(interval = 5000)
    public R<Long> create(@Valid @RequestBody UserCreateDTO dto) {
        return R.ok(userService.create(dto));
    }

    @GetMapping("/export")
    @SaCheckPermission("system:user:export")
    @Log(module = "用户管理", operationType = OperationType.EXPORT)
    public void export(UserQuery query, HttpServletResponse response) {
        userService.export(query, response);
    }
}
```

```java
// VO 自动翻译 + 脱敏
@Data
public class UserVO {
    private Long id;
    private String username;

    @Sensitive(strategy = SensitiveStrategy.PHONE)
    private String phone;           // 输出: 138****8888

    @Sensitive(strategy = SensitiveStrategy.EMAIL)
    private String email;           // 输出: z**@example.com

    @DictFormat("sys_user_status")
    private Integer status;         // 自动添加 statusLabel: "正常"

    @DataFill(container = "dept", props = @Prop(ref = "deptName"))
    private Long deptId;
    private String deptName;        // 自动填充部门名称
}
```

---

## 七、技术选型详情 (优化版)

| 分类 | 技术 | 版本 | 说明 | 参考来源 |
|------|------|------|------|---------|
| **基础框架** | Spring Boot | 4.x | 基于 Spring Framework 7 | - |
| | Spring Cloud | 2025.x | 微服务支持 (可选) | Pig |
| **JDK** | OpenJDK | 21+ LTS | Virtual Threads, Records | - |
| **构建** | Maven | 3.9+ | 依赖管理 | - |
| **权限认证** | **Sa-Token** | 1.44+ | 轻量级权限框架 | RuoYi-Plus/ContiNew |
| | Spring Security | 6.x | 可选，复杂场景 | - |
| **ORM** | MyBatis-Plus | 4.x | 增强 CRUD | - |
| | Dynamic Datasource | 4.x | 动态数据源 | - |
| **缓存** | **JetCache** | 2.7+ | 多级缓存注解 | ContiNew |
| | Redis | 7.x | 分布式缓存 | - |
| | Redisson | 3.49+ | 分布式锁 | ContiNew |
| **数据库** | MySQL | 8.x | 主数据库 | - |
| | **Liquibase** | 4.27+ | 数据库版本管理 | ContiNew |
| | HikariCP | 5.x | 连接池 | - |
| **ID 生成** | **CosId** | 2.x | 雪花算法增强 | ContiNew |
| **文件存储** | **X File Storage** | 2.2+ | 统一存储抽象 | ContiNew |
| **Excel** | **FastExcel** | 1.2+ | 高性能 Excel | ContiNew |
| **数据填充** | **Crane4j** | 2.9+ | 关联数据填充 | ContiNew |
| **三方登录** | **JustAuth** | 1.16+ | 多平台登录 | RuoYi-Plus |
| **API 文档** | **Knife4j** | 4.x | Swagger 增强 | 多项目 |
| | SpringDoc | 2.x | OpenAPI 3 | - |
| **校验** | Hibernate Validator | 8.x | 参数校验 | - |
| **序列化** | Jackson | 2.17+ | JSON 处理 | - |
| **日志** | SLF4J + Logback | 2.x / 1.5+ | 日志框架 | - |
| **监控** | Micrometer | 1.13+ | 指标采集 | - |
| | Spring Boot Admin | 3.x | 服务监控 | Pig |
| **消息队列** | RabbitMQ / Kafka | 3.x | 可选 | - |
| **定时任务** | XXL-Job | 2.x | 分布式任务 | - |

---

## 八、业务快速集成指南

### 8.1 Step 1: 引入依赖

```xml
<!-- 业务项目 pom.xml -->
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>com.platform</groupId>
            <artifactId>platform-dependencies</artifactId>
            <version>1.0.0</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>

<dependencies>
    <!-- 必选: Web + 安全 + 数据 一站式启动器 -->
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-spring-boot-starter-security</artifactId>
    </dependency>
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-spring-boot-starter-mybatis</artifactId>
    </dependency>

    <!-- 可选: 按需引入 -->
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-spring-boot-starter-redis</artifactId>
    </dependency>
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-spring-boot-starter-excel</artifactId>
    </dependency>
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-spring-boot-starter-oss</artifactId>
    </dependency>
    <dependency>
        <groupId>com.platform</groupId>
        <artifactId>platform-spring-boot-starter-tenant</artifactId>
    </dependency>
</dependencies>
```

### 8.2 Step 2: 最小配置

```yaml
# application.yml
platform:
  # Web 配置
  web:
    cors:
      enabled: true
      allowed-origins: "*"

  # Sa-Token 安全配置
  security:
    token-name: Authorization
    timeout: 86400
    is-concurrent: true
    is-share: false
    ignore-urls:
      - /api/auth/login
      - /api/auth/register
      - /doc.html
      - /webjars/**

  # MyBatis 配置
  mybatis:
    mapper-locations: classpath*:mapper/**/*.xml
    logic-delete-field: deleted

  # 多租户配置 (可选)
  tenant:
    enabled: false
    column: tenant_id
    ignore-tables:
      - sys_config
      - sys_dict

spring:
  datasource:
    url: jdbc:mysql://localhost:3306/platform?useSSL=false&serverTimezone=Asia/Shanghai
    username: root
    password: ${DB_PASSWORD}
  data:
    redis:
      host: localhost
      port: 6379

# Liquibase 数据库版本管理
  liquibase:
    enabled: true
    change-log: classpath:db/changelog/master.xml
```

### 8.3 Step 3: 5 分钟完成 CRUD

```java
// 1. 定义 DO
@Data
@TableName("sys_user")
public class UserDO extends BaseDO {
    private String username;
    private String nickname;
    private String phone;
    private String email;
    private Integer status;
    private Long deptId;
}

// 2. 定义 DTO/VO
@Data
public class UserCreateDTO {
    @NotBlank(message = "用户名不能为空")
    private String username;
    private String nickname;
    private String phone;
}

@Data
public class UserVO {
    private Long id;
    private String username;

    @Sensitive(strategy = SensitiveStrategy.PHONE)
    private String phone;

    @DictFormat("sys_user_status")
    private Integer status;
}

// 3. 定义 Service (继承 BaseService 即拥有完整 CRUD)
public interface UserService extends BaseService<UserDO, Long, UserQuery, UserCreateDTO, UserVO> {
}

@Service
public class UserServiceImpl
    extends BaseServiceImpl<UserMapper, UserDO, Long, UserQuery, UserCreateDTO, UserVO>
    implements UserService {
}

// 4. 定义 Controller
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {
    private final UserService userService;

    @GetMapping
    @SaCheckPermission("system:user:list")
    public R<PageResult<UserVO>> page(UserQuery query) {
        return R.ok(userService.page(query));
    }

    @PostMapping
    @SaCheckPermission("system:user:add")
    @RepeatSubmit
    public R<Long> create(@Valid @RequestBody UserCreateDTO dto) {
        return R.ok(userService.create(dto));
    }

    @PutMapping("/{id}")
    @SaCheckPermission("system:user:edit")
    public R<Boolean> update(@PathVariable Long id, @Valid @RequestBody UserCreateDTO dto) {
        return R.ok(userService.update(id, dto));
    }

    @DeleteMapping
    @SaCheckPermission("system:user:delete")
    public R<Boolean> delete(@RequestBody List<Long> ids) {
        return R.ok(userService.delete(ids));
    }

    @GetMapping("/export")
    @SaCheckPermission("system:user:export")
    public void export(UserQuery query, HttpServletResponse response) {
        userService.export(query, response);
    }
}
```

---

## 九、SPI 扩展机制

### 9.1 可扩展点列表

| 扩展点 | 接口 | 说明 |
|--------|------|------|
| 认证方式 | `AuthenticationProvider` | 短信、OAuth、LDAP 等 |
| 权限校验 | `PermissionHandler` | 自定义权限逻辑 |
| 数据权限 | `DataScopeHandler` | 自定义数据权限规则 |
| 操作日志 | `OperationLogHandler` | 自定义日志存储 |
| 异常转换 | `ExceptionTranslator` | 自定义异常处理 |
| ID 生成 | `IdGenerator` | 自定义 ID 策略 |
| 租户识别 | `TenantResolver` | 自定义租户识别 |
| 文件存储 | `FileStorage` | 自定义存储实现 |
| 字典翻译 | `DictDataProvider` | 自定义字典来源 |
| 数据填充 | `Container` | 自定义数据填充源 |

### 9.2 扩展示例

```java
// 自定义数据权限处理器
@Component
public class CustomDataScopeHandler implements DataScopeHandler {

    @Override
    public String buildScopeSql(DataScopeType type, String alias, LoginUser user) {
        return switch (type) {
            case ALL -> "";
            case DEPT -> String.format("%s.dept_id IN (%s)", alias,
                String.join(",", user.getDeptAndChildIds()));
            case SELF -> String.format("%s.create_by = %d", alias, user.getId());
            case CUSTOM -> buildCustomScope(alias, user);
        };
    }
}

// 自定义字典数据提供者 (支持从数据库/Redis/远程服务获取)
@Component
public class DatabaseDictProvider implements DictDataProvider {

    @Override
    public String getLabel(String dictType, String value) {
        return dictService.getLabel(dictType, value);
    }
}
```

---

## 十、开源协议

**Apache License 2.0**

- 允许商业使用
- 允许修改和分发
- 必须保留版权声明
- 不提供任何担保

---

## 十一、路线图

### Phase 1: 核心基础 (v1.0)
- [ ] platform-dependencies BOM
- [ ] platform-common-core 核心组件
- [ ] platform-common-web Web 层
- [ ] platform-common-mybatis 数据层
- [ ] platform-spring-boot-starter-web
- [ ] platform-spring-boot-starter-mybatis

### Phase 2: 安全 & 缓存 (v1.1)
- [ ] platform-common-security (Sa-Token)
- [ ] platform-common-redis (JetCache)
- [ ] platform-spring-boot-starter-security
- [ ] platform-spring-boot-starter-redis

### Phase 3: 企业特性 (v1.2)
- [ ] platform-common-tenant 多租户
- [ ] platform-common-log 操作日志
- [ ] platform-common-excel (FastExcel)
- [ ] platform-common-oss (X File Storage)
- [ ] platform-module-system 系统模块

### Phase 4: 可视化 & 微服务 (v2.0)
- [ ] platform-visual-codegen 代码生成
- [ ] platform-visual-monitor 服务监控
- [ ] platform-gateway 微服务网关
- [ ] platform-register 注册中心
- [ ] 完整文档和示例

---

## 参考资料

- [RuoYi-Vue-Pro 开发指南](https://doc.iocoder.cn/)
- [JeecgBoot 文档中心](https://help.jeecg.com/)
- [Pig 微服务框架](https://gitee.com/log4j/pig)
- [SpringBlade 开发手册](https://www.kancloud.cn/smallchill/blade)
- [ContiNew Admin](https://github.com/continew-org/continew-admin)
- [Sa-Token 官方文档](https://sa-token.cc/)
- [JetCache 官方文档](https://github.com/alibaba/jetcache)
- [X File Storage](https://github.com/dromara/x-file-storage)
