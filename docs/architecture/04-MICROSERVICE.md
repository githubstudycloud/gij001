# 04 - 微服务框架设计

## 一、多语言框架选型

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            多语言微服务框架                                          │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                              Java 框架栈                                     │   │
│  │                                                                             │   │
│  │   Spring Boot 3.x ──▶ Spring Cloud Alibaba ──▶ 生产就绪                    │   │
│  │        │                      │                                             │   │
│  │        ├── Nacos (配置/注册)  │                                             │   │
│  │        ├── Sentinel (限流熔断) │                                             │   │
│  │        ├── Seata (分布式事务)  │                                             │   │
│  │        ├── Dubbo 3 (RPC)      │                                             │   │
│  │        └── RocketMQ (消息)    │                                             │   │
│  │                                                                             │   │
│  │   兼容: Spring Boot 2.x / 1.x (通过 Starter 适配)                          │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                              Go 框架栈                                       │   │
│  │                                                                             │   │
│  │   Go-Zero / Kratos ──▶ 高性能服务                                          │   │
│  │        │                                                                    │   │
│  │        ├── 内置服务发现                                                     │   │
│  │        ├── 内置限流熔断                                                     │   │
│  │        ├── gRPC + HTTP 双协议                                              │   │
│  │        └── 代码生成工具                                                     │   │
│  │                                                                             │   │
│  │   兼容: Gin (老项目适配器)                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                            Python 框架栈                                     │   │
│  │                                                                             │   │
│  │   FastAPI ──▶ 异步高性能 API                                               │   │
│  │        │                                                                    │   │
│  │        ├── Pydantic (数据验证)                                             │   │
│  │        ├── SQLAlchemy (ORM)                                                │   │
│  │        ├── Celery (异步任务)                                               │   │
│  │        └── OpenTelemetry (可观测)                                          │   │
│  │                                                                             │   │
│  │   兼容: Django / Flask (老项目适配器)                                       │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、Java 平台框架

### 2.1 依赖管理 BOM

```xml
<!-- platform-dependencies/pom.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.platform</groupId>
    <artifactId>platform-dependencies</artifactId>
    <version>1.0.0</version>
    <packaging>pom</packaging>

    <properties>
        <!-- 基础版本 -->
        <java.version>21</java.version>
        <spring-boot.version>3.2.1</spring-boot.version>
        <spring-cloud.version>2023.0.0</spring-cloud.version>
        <spring-cloud-alibaba.version>2023.0.0.0</spring-cloud-alibaba.version>

        <!-- 中间件版本 -->
        <mybatis-plus.version>3.5.5</mybatis-plus.version>
        <redisson.version>3.25.0</redisson.version>
        <rocketmq.version>2.2.3</rocketmq.version>
        <seata.version>2.0.0</seata.version>
        <xxl-job.version>2.4.0</xxl-job.version>

        <!-- 工具版本 -->
        <hutool.version>5.8.24</hutool.version>
        <mapstruct.version>1.5.5.Final</mapstruct.version>
        <knife4j.version>4.4.0</knife4j.version>

        <!-- 可观测性 -->
        <otel.version>1.32.0</otel.version>
        <logstash-logback.version>7.4</logstash-logback.version>
    </properties>

    <dependencyManagement>
        <dependencies>
            <!-- Spring Boot -->
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>${spring-boot.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>

            <!-- Spring Cloud -->
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>

            <!-- Spring Cloud Alibaba -->
            <dependency>
                <groupId>com.alibaba.cloud</groupId>
                <artifactId>spring-cloud-alibaba-dependencies</artifactId>
                <version>${spring-cloud-alibaba.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>

            <!-- 平台公共模块 -->
            <dependency>
                <groupId>com.platform</groupId>
                <artifactId>platform-common-core</artifactId>
                <version>${project.version}</version>
            </dependency>
            <dependency>
                <groupId>com.platform</groupId>
                <artifactId>platform-common-web</artifactId>
                <version>${project.version}</version>
            </dependency>
            <dependency>
                <groupId>com.platform</groupId>
                <artifactId>platform-common-security</artifactId>
                <version>${project.version}</version>
            </dependency>
            <dependency>
                <groupId>com.platform</groupId>
                <artifactId>platform-common-mybatis</artifactId>
                <version>${project.version}</version>
            </dependency>
            <dependency>
                <groupId>com.platform</groupId>
                <artifactId>platform-common-redis</artifactId>
                <version>${project.version}</version>
            </dependency>
            <dependency>
                <groupId>com.platform</groupId>
                <artifactId>platform-common-mq</artifactId>
                <version>${project.version}</version>
            </dependency>
            <dependency>
                <groupId>com.platform</groupId>
                <artifactId>platform-common-log</artifactId>
                <version>${project.version}</version>
            </dependency>

            <!-- 平台 Starters -->
            <dependency>
                <groupId>com.platform</groupId>
                <artifactId>platform-starter-web</artifactId>
                <version>${project.version}</version>
            </dependency>
            <!-- ... 其他 Starters -->

            <!-- MyBatis Plus -->
            <dependency>
                <groupId>com.baomidou</groupId>
                <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
                <version>${mybatis-plus.version}</version>
            </dependency>

            <!-- Redisson -->
            <dependency>
                <groupId>org.redisson</groupId>
                <artifactId>redisson-spring-boot-starter</artifactId>
                <version>${redisson.version}</version>
            </dependency>

            <!-- Knife4j -->
            <dependency>
                <groupId>com.github.xiaoymin</groupId>
                <artifactId>knife4j-openapi3-jakarta-spring-boot-starter</artifactId>
                <version>${knife4j.version}</version>
            </dependency>

            <!-- 工具类 -->
            <dependency>
                <groupId>cn.hutool</groupId>
                <artifactId>hutool-all</artifactId>
                <version>${hutool.version}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>
</project>
```

### 2.2 核心 Common 模块

```java
// ==================== platform-common-core ====================

// 统一响应
@Data
@AllArgsConstructor
@NoArgsConstructor
public class R<T> implements Serializable {
    private int code;
    private String message;
    private T data;
    private String traceId;
    private long timestamp;

    public static <T> R<T> ok() {
        return ok(null);
    }

    public static <T> R<T> ok(T data) {
        return new R<>(0, "success", data, TraceContext.getTraceId(), System.currentTimeMillis());
    }

    public static <T> R<T> fail(String message) {
        return fail(ResultCode.FAILURE, message);
    }

    public static <T> R<T> fail(IResultCode resultCode) {
        return fail(resultCode, resultCode.getMessage());
    }

    public static <T> R<T> fail(IResultCode resultCode, String message) {
        return new R<>(resultCode.getCode(), message, null, TraceContext.getTraceId(), System.currentTimeMillis());
    }
}

// 错误码接口
public interface IResultCode {
    int getCode();
    String getMessage();
}

// 通用错误码
@Getter
@AllArgsConstructor
public enum ResultCode implements IResultCode {
    SUCCESS(0, "操作成功"),
    FAILURE(-1, "操作失败"),

    // 1xxxxx 通用错误
    PARAM_ERROR(100001, "参数错误"),
    DATA_NOT_FOUND(100002, "数据不存在"),
    DATA_DUPLICATE(100003, "数据重复"),

    // 2xxxxx 用户相关
    USER_NOT_LOGIN(200001, "用户未登录"),
    USER_NOT_FOUND(200002, "用户不存在"),
    USER_PASSWORD_ERROR(200003, "密码错误"),
    USER_DISABLED(200004, "用户已禁用"),

    // 3xxxxx 权限相关
    NO_PERMISSION(300001, "无操作权限"),
    TOKEN_INVALID(300002, "Token 无效"),
    TOKEN_EXPIRED(300003, "Token 已过期"),

    // 4xxxxx 业务错误
    BIZ_ERROR(400001, "业务异常"),
    ORDER_NOT_FOUND(400101, "订单不存在"),
    STOCK_NOT_ENOUGH(400201, "库存不足"),

    // 5xxxxx 系统错误
    SYSTEM_ERROR(500001, "系统错误"),
    SERVICE_UNAVAILABLE(500002, "服务不可用"),
    RATE_LIMIT(500003, "请求过于频繁");

    private final int code;
    private final String message;
}

// 业务异常
@Getter
public class BizException extends RuntimeException {
    private final int code;
    private final String message;

    public BizException(IResultCode resultCode) {
        super(resultCode.getMessage());
        this.code = resultCode.getCode();
        this.message = resultCode.getMessage();
    }

    public BizException(IResultCode resultCode, String message) {
        super(message);
        this.code = resultCode.getCode();
        this.message = message;
    }

    public BizException(int code, String message) {
        super(message);
        this.code = code;
        this.message = message;
    }
}

// 分页请求
@Data
public class PageQuery {
    @Min(1)
    private int pageNum = 1;

    @Min(1)
    @Max(1000)
    private int pageSize = 10;

    private String orderBy;
    private String orderDirection = "DESC";

    public <T> Page<T> toPage() {
        return new Page<>(pageNum, pageSize);
    }
}

// 分页响应
@Data
@AllArgsConstructor
@NoArgsConstructor
public class PageResult<T> {
    private List<T> records;
    private long total;
    private int pageNum;
    private int pageSize;
    private int pages;

    public static <T> PageResult<T> of(IPage<T> page) {
        return new PageResult<>(
            page.getRecords(),
            page.getTotal(),
            (int) page.getCurrent(),
            (int) page.getSize(),
            (int) page.getPages()
        );
    }
}

// 基础实体
@Data
public abstract class BaseEntity implements Serializable {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    @TableField(fill = FieldFill.INSERT)
    private Long createdBy;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdTime;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private Long updatedBy;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedTime;

    @TableLogic
    private Integer deleted;
}

// 租户实体
@Data
@EqualsAndHashCode(callSuper = true)
public abstract class TenantEntity extends BaseEntity {
    private Long tenantId;
}
```

### 2.3 Web Starter

```java
// ==================== platform-starter-web ====================

@Configuration
@EnableConfigurationProperties(PlatformWebProperties.class)
@Import({
    GlobalExceptionHandler.class,
    LogContextFilter.class,
    TenantInterceptor.class,
    CorsConfig.class
})
public class PlatformWebAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        mapper.setDateFormat(new SimpleDateFormat("yyyy-MM-dd HH:mm:ss"));
        mapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);
        mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        return mapper;
    }

    @Bean
    public WebMvcConfigurer platformWebMvcConfigurer(TenantInterceptor tenantInterceptor) {
        return new WebMvcConfigurer() {
            @Override
            public void addInterceptors(InterceptorRegistry registry) {
                registry.addInterceptor(tenantInterceptor)
                    .addPathPatterns("/api/**")
                    .excludePathPatterns("/api/auth/**");
            }
        };
    }
}

// 全局异常处理
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(BizException.class)
    public R<Void> handleBizException(BizException e) {
        log.warn("业务异常: {}", e.getMessage());
        return R.fail(e.getCode(), e.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public R<Void> handleValidException(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
            .map(f -> f.getField() + ": " + f.getDefaultMessage())
            .collect(Collectors.joining(", "));
        return R.fail(ResultCode.PARAM_ERROR, message);
    }

    @ExceptionHandler(Exception.class)
    public R<Void> handleException(Exception e) {
        log.error("系统异常", e);
        return R.fail(ResultCode.SYSTEM_ERROR);
    }
}

// 日志上下文 Filter
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class LogContextFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        try {
            MDC.put("requestId", getOrGenerateRequestId(request));
            MDC.put("clientIp", getClientIp(request));
            MDC.put("uri", request.getRequestURI());
            MDC.put("method", request.getMethod());

            chain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }
}

// 租户拦截器
@Component
public class TenantInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response,
                            Object handler) throws Exception {
        String tenantId = request.getHeader("X-Tenant-Id");
        if (StringUtils.hasText(tenantId)) {
            TenantContext.setTenantId(Long.valueOf(tenantId));
        }
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
                               Object handler, Exception ex) throws Exception {
        TenantContext.clear();
    }
}
```

### 2.4 MyBatis Starter

```java
// ==================== platform-starter-mybatis ====================

@Configuration
@MapperScan(basePackages = "${platform.mybatis.mapper-scan:com.**.mapper}")
public class PlatformMyBatisAutoConfiguration {

    /**
     * 分页插件 + 多租户插件
     */
    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor(
            @Autowired(required = false) TenantLineHandler tenantLineHandler) {

        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();

        // 多租户插件
        if (tenantLineHandler != null) {
            interceptor.addInnerInterceptor(new TenantLineInnerInterceptor(tenantLineHandler));
        }

        // 分页插件
        PaginationInnerInterceptor paginationInterceptor = new PaginationInnerInterceptor(DbType.MYSQL);
        paginationInterceptor.setMaxLimit(1000L);
        interceptor.addInnerInterceptor(paginationInterceptor);

        // 乐观锁插件
        interceptor.addInnerInterceptor(new OptimisticLockerInnerInterceptor());

        // 防全表更新删除
        interceptor.addInnerInterceptor(new BlockAttackInnerInterceptor());

        return interceptor;
    }

    /**
     * 多租户处理器
     */
    @Bean
    @ConditionalOnProperty(name = "platform.tenant.enabled", havingValue = "true")
    public TenantLineHandler tenantLineHandler() {
        return new TenantLineHandler() {
            @Override
            public Expression getTenantId() {
                Long tenantId = TenantContext.getTenantId();
                return new LongValue(tenantId != null ? tenantId : 0L);
            }

            @Override
            public String getTenantIdColumn() {
                return "tenant_id";
            }

            @Override
            public boolean ignoreTable(String tableName) {
                // 忽略不需要租户隔离的表
                return Arrays.asList("sys_tenant", "sys_config").contains(tableName);
            }
        };
    }

    /**
     * 自动填充
     */
    @Bean
    public MetaObjectHandler metaObjectHandler() {
        return new MetaObjectHandler() {
            @Override
            public void insertFill(MetaObject metaObject) {
                Long userId = UserContext.getUserId();
                this.strictInsertFill(metaObject, "createdBy", Long.class, userId);
                this.strictInsertFill(metaObject, "createdTime", LocalDateTime.class, LocalDateTime.now());
                this.strictInsertFill(metaObject, "updatedBy", Long.class, userId);
                this.strictInsertFill(metaObject, "updatedTime", LocalDateTime.class, LocalDateTime.now());
                this.strictInsertFill(metaObject, "deleted", Integer.class, 0);

                // 租户ID
                Long tenantId = TenantContext.getTenantId();
                if (tenantId != null) {
                    this.strictInsertFill(metaObject, "tenantId", Long.class, tenantId);
                }
            }

            @Override
            public void updateFill(MetaObject metaObject) {
                this.strictUpdateFill(metaObject, "updatedBy", Long.class, UserContext.getUserId());
                this.strictUpdateFill(metaObject, "updatedTime", LocalDateTime.class, LocalDateTime.now());
            }
        };
    }
}
```

## 三、Go 平台框架

### 3.1 公共包结构

```go
// platform-framework/go/pkg/

// ==================== response/response.go ====================
package response

import (
    "net/http"
    "github.com/gin-gonic/gin"
)

type Response struct {
    Code      int         `json:"code"`
    Message   string      `json:"message"`
    Data      interface{} `json:"data,omitempty"`
    TraceID   string      `json:"traceId,omitempty"`
    Timestamp int64       `json:"timestamp"`
}

type PageResult struct {
    Records  interface{} `json:"records"`
    Total    int64       `json:"total"`
    PageNum  int         `json:"pageNum"`
    PageSize int         `json:"pageSize"`
    Pages    int         `json:"pages"`
}

func Success(c *gin.Context, data interface{}) {
    c.JSON(http.StatusOK, Response{
        Code:      0,
        Message:   "success",
        Data:      data,
        TraceID:   c.GetString("traceId"),
        Timestamp: time.Now().UnixMilli(),
    })
}

func Fail(c *gin.Context, code int, message string) {
    c.JSON(http.StatusOK, Response{
        Code:      code,
        Message:   message,
        TraceID:   c.GetString("traceId"),
        Timestamp: time.Now().UnixMilli(),
    })
}

func FailWithError(c *gin.Context, err error) {
    if bizErr, ok := err.(*BizError); ok {
        Fail(c, bizErr.Code, bizErr.Message)
        return
    }
    Fail(c, 500001, "系统错误")
}

// ==================== errors/errors.go ====================
package errors

type BizError struct {
    Code    int
    Message string
}

func (e *BizError) Error() string {
    return e.Message
}

func NewBizError(code int, message string) *BizError {
    return &BizError{Code: code, Message: message}
}

// 预定义错误
var (
    ErrParamInvalid   = NewBizError(100001, "参数错误")
    ErrDataNotFound   = NewBizError(100002, "数据不存在")
    ErrUnauthorized   = NewBizError(200001, "未授权")
    ErrNoPermission   = NewBizError(300001, "无权限")
    ErrSystemInternal = NewBizError(500001, "系统错误")
)

// ==================== middleware/logging.go ====================
package middleware

import (
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
    "go.uber.org/zap"
)

func LoggingMiddleware(logger *zap.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()

        // 生成 requestId
        requestId := c.GetHeader("X-Request-ID")
        if requestId == "" {
            requestId = uuid.New().String()
        }
        c.Set("requestId", requestId)

        // 获取 traceId (from OTel)
        traceId := trace.SpanFromContext(c.Request.Context()).SpanContext().TraceID().String()
        c.Set("traceId", traceId)

        c.Next()

        // 记录请求日志
        logger.Info("request",
            zap.String("method", c.Request.Method),
            zap.String("path", c.Request.URL.Path),
            zap.Int("status", c.Writer.Status()),
            zap.Duration("latency", time.Since(start)),
            zap.String("clientIP", c.ClientIP()),
            zap.String("requestId", requestId),
            zap.String("traceId", traceId),
        )
    }
}

// ==================== middleware/tenant.go ====================
package middleware

func TenantMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        tenantId := c.GetHeader("X-Tenant-Id")
        if tenantId != "" {
            c.Set("tenantId", tenantId)
        }
        c.Next()
    }
}

// ==================== config/config.go ====================
package config

type Config struct {
    Server   ServerConfig   `yaml:"server"`
    Database DatabaseConfig `yaml:"database"`
    Redis    RedisConfig    `yaml:"redis"`
    Nacos    NacosConfig    `yaml:"nacos"`
    OTEL     OTELConfig     `yaml:"otel"`
}

type ServerConfig struct {
    Port int    `yaml:"port"`
    Name string `yaml:"name"`
    Env  string `yaml:"env"`
}

func LoadConfig(path string) (*Config, error) {
    // 从 Nacos 或本地文件加载配置
}
```

### 3.2 Go 服务模板

```go
// file-service/main.go
package main

import (
    "context"
    "github.com/gin-gonic/gin"
    "platform/pkg/config"
    "platform/pkg/middleware"
    "platform/pkg/trace"
)

func main() {
    // 加载配置
    cfg, _ := config.LoadConfig("config.yaml")

    // 初始化 OTel
    shutdown := trace.InitTracer(cfg.Server.Name, cfg.OTEL.Endpoint)
    defer shutdown(context.Background())

    // 初始化 Gin
    r := gin.New()

    // 中间件
    r.Use(gin.Recovery())
    r.Use(middleware.LoggingMiddleware(logger))
    r.Use(middleware.TenantMiddleware())
    r.Use(otelgin.Middleware(cfg.Server.Name))

    // 路由
    api := r.Group("/api/v1")
    {
        files := api.Group("/files")
        {
            files.POST("/upload", handler.Upload)
            files.GET("/:id", handler.Download)
            files.DELETE("/:id", handler.Delete)
        }
    }

    // 健康检查
    r.GET("/health", func(c *gin.Context) {
        c.JSON(200, gin.H{"status": "ok"})
    })

    r.Run(fmt.Sprintf(":%d", cfg.Server.Port))
}
```

## 四、Python 平台框架

### 4.1 公共包结构

```python
# platform-framework/python/platform_common/

# ==================== response.py ====================
from pydantic import BaseModel
from typing import Optional, Generic, TypeVar, List
from datetime import datetime
import time

T = TypeVar('T')

class Response(BaseModel, Generic[T]):
    code: int = 0
    message: str = "success"
    data: Optional[T] = None
    trace_id: Optional[str] = None
    timestamp: int = int(time.time() * 1000)

    @classmethod
    def success(cls, data: T = None, trace_id: str = None):
        return cls(code=0, message="success", data=data, trace_id=trace_id)

    @classmethod
    def fail(cls, code: int, message: str, trace_id: str = None):
        return cls(code=code, message=message, trace_id=trace_id)


class PageResult(BaseModel, Generic[T]):
    records: List[T]
    total: int
    page_num: int
    page_size: int
    pages: int


# ==================== errors.py ====================
class BizException(Exception):
    def __init__(self, code: int, message: str):
        self.code = code
        self.message = message
        super().__init__(message)


class ErrorCode:
    PARAM_ERROR = (100001, "参数错误")
    DATA_NOT_FOUND = (100002, "数据不存在")
    UNAUTHORIZED = (200001, "未授权")
    NO_PERMISSION = (300001, "无权限")
    SYSTEM_ERROR = (500001, "系统错误")


# ==================== middleware.py ====================
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
import uuid
from opentelemetry import trace

class LoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Request ID
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.state.request_id = request_id

        # Trace ID
        span = trace.get_current_span()
        trace_id = span.get_span_context().trace_id if span else None
        request.state.trace_id = format(trace_id, '032x') if trace_id else None

        # Tenant ID
        tenant_id = request.headers.get("X-Tenant-Id")
        request.state.tenant_id = tenant_id

        response = await call_next(request)
        return response


# ==================== config.py ====================
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Server
    server_name: str = "python-service"
    server_port: int = 8000
    env: str = "dev"

    # Database
    db_host: str = "localhost"
    db_port: int = 3306
    db_name: str = "platform"
    db_user: str = "root"
    db_password: str = ""

    # Redis
    redis_host: str = "localhost"
    redis_port: int = 6379

    # OTEL
    otel_endpoint: str = "http://otel-collector:4317"

    class Config:
        env_file = ".env"


settings = Settings()
```

### 4.2 FastAPI 服务模板

```python
# search-service/main.py
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from platform_common.response import Response
from platform_common.errors import BizException
from platform_common.middleware import LoggingMiddleware
from platform_common.config import settings
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

app = FastAPI(title=settings.server_name)

# OTel 自动埋点
FastAPIInstrumentor.instrument_app(app)

# 中间件
app.add_middleware(LoggingMiddleware)


# 全局异常处理
@app.exception_handler(BizException)
async def biz_exception_handler(request: Request, exc: BizException):
    return JSONResponse(
        status_code=200,
        content=Response.fail(
            code=exc.code,
            message=exc.message,
            trace_id=getattr(request.state, 'trace_id', None)
        ).dict()
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content=Response.fail(
            code=500001,
            message="系统错误",
            trace_id=getattr(request.state, 'trace_id', None)
        ).dict()
    )


# 路由
@app.get("/api/v1/search")
async def search(q: str, page: int = 1, size: int = 10):
    results = await search_service.search(q, page, size)
    return Response.success(results)


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=settings.server_port)
```

## 五、服务间通信

### 5.1 通信方式选择

| 场景 | 协议 | 适用 |
|------|------|------|
| Java ↔ Java | OpenFeign / Dubbo 3 | 内部服务调用 |
| Java ↔ Go | gRPC | 高性能场景 |
| Java ↔ Python | HTTP / gRPC | 灵活选择 |
| Go ↔ Go | gRPC | 默认选择 |
| 异步解耦 | RocketMQ | 事件驱动 |

### 5.2 gRPC 定义

```protobuf
// proto/user.proto
syntax = "proto3";

package platform.user.v1;

option go_package = "platform/api/user/v1;v1";
option java_package = "com.platform.api.user.v1";
option java_multiple_files = true;

service UserService {
    rpc GetUser(GetUserRequest) returns (GetUserResponse);
    rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
}

message GetUserRequest {
    int64 user_id = 1;
}

message GetUserResponse {
    User user = 1;
}

message User {
    int64 id = 1;
    string username = 2;
    string nickname = 3;
    string email = 4;
    string phone = 5;
    int32 status = 6;
    int64 created_time = 7;
}
```

## 六、服务治理

### 6.1 限流熔断 - Sentinel

```java
// Java 配置
@Configuration
public class SentinelConfig {

    @Bean
    public SentinelResourceAspect sentinelResourceAspect() {
        return new SentinelResourceAspect();
    }

    @PostConstruct
    public void initFlowRules() {
        List<FlowRule> rules = new ArrayList<>();

        // 接口限流
        FlowRule rule = new FlowRule();
        rule.setResource("createOrder");
        rule.setGrade(RuleConstant.FLOW_GRADE_QPS);
        rule.setCount(1000);  // QPS 上限
        rule.setControlBehavior(RuleConstant.CONTROL_BEHAVIOR_WARM_UP);
        rule.setWarmUpPeriodSec(10);
        rules.add(rule);

        FlowRuleManager.loadRules(rules);
    }
}

// 使用
@Service
public class OrderService {

    @SentinelResource(value = "createOrder",
        blockHandler = "createOrderBlockHandler",
        fallback = "createOrderFallback")
    public Order createOrder(CreateOrderRequest request) {
        // 业务逻辑
    }

    public Order createOrderBlockHandler(CreateOrderRequest request, BlockException e) {
        throw new BizException(ResultCode.RATE_LIMIT);
    }

    public Order createOrderFallback(CreateOrderRequest request, Throwable t) {
        throw new BizException(ResultCode.SERVICE_UNAVAILABLE);
    }
}
```

### 6.2 分布式事务 - Seata

```java
// AT 模式示例
@Service
public class OrderService {

    @Autowired
    private OrderMapper orderMapper;

    @Autowired
    private StockFeignClient stockClient;

    @GlobalTransactional(name = "create-order", rollbackFor = Exception.class)
    public Order createOrder(CreateOrderRequest request) {
        // 1. 创建订单（本地事务）
        Order order = new Order();
        order.setUserId(request.getUserId());
        order.setTotalAmount(request.getTotalAmount());
        orderMapper.insert(order);

        // 2. 扣减库存（远程调用，也在全局事务中）
        stockClient.deduct(new StockDeductRequest(
            request.getProductId(),
            request.getQuantity()
        ));

        return order;
    }
}
```
