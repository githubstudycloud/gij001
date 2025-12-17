# 07 - 安全体系设计

## 一、安全架构总览

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              安全防护体系                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           网络安全层                                         │   │
│  │  WAF → DDoS 防护 → IP 黑白名单 → 限流 → 网关认证                           │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           应用安全层                                         │   │
│  │  认证 (OAuth2/JWT) → 授权 (RBAC) → 数据权限 → 接口签名                     │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           数据安全层                                         │   │
│  │  传输加密 (TLS) → 存储加密 → 字段脱敏 → 密钥管理                           │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           审计安全层                                         │   │
│  │  操作审计 → 登录审计 → 数据访问审计 → 安全事件                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、认证授权

### 2.1 OAuth2 + JWT 认证

```java
// 认证服务配置
@Configuration
@EnableAuthorizationServer
public class AuthorizationServerConfig extends AuthorizationServerConfigurerAdapter {

    @Override
    public void configure(ClientDetailsServiceConfigurer clients) throws Exception {
        clients.inMemory()
            .withClient("web-client")
            .secret(passwordEncoder.encode("secret"))
            .authorizedGrantTypes("password", "refresh_token")
            .scopes("read", "write")
            .accessTokenValiditySeconds(3600)
            .refreshTokenValiditySeconds(86400);
    }

    @Bean
    public JwtAccessTokenConverter accessTokenConverter() {
        JwtAccessTokenConverter converter = new JwtAccessTokenConverter();
        converter.setSigningKey(jwtSigningKey);
        return converter;
    }
}
```

### 2.2 RBAC 权限模型

```sql
-- 用户表
CREATE TABLE sys_user (
    id BIGINT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    password VARCHAR(100) NOT NULL,
    status TINYINT DEFAULT 1,
    tenant_id BIGINT NOT NULL
);

-- 角色表
CREATE TABLE sys_role (
    id BIGINT PRIMARY KEY,
    role_code VARCHAR(50) NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    tenant_id BIGINT NOT NULL
);

-- 权限表
CREATE TABLE sys_permission (
    id BIGINT PRIMARY KEY,
    perm_code VARCHAR(100) NOT NULL,
    perm_name VARCHAR(100) NOT NULL,
    resource_type VARCHAR(20) -- menu, button, api
);

-- 用户角色关联
CREATE TABLE sys_user_role (
    user_id BIGINT,
    role_id BIGINT,
    PRIMARY KEY (user_id, role_id)
);

-- 角色权限关联
CREATE TABLE sys_role_permission (
    role_id BIGINT,
    permission_id BIGINT,
    PRIMARY KEY (role_id, permission_id)
);
```

### 2.3 数据权限

```java
// 数据权限注解
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface DataScope {
    String deptAlias() default "d";
    String userAlias() default "u";
}

// 数据权限拦截器
@Aspect
@Component
public class DataScopeAspect {

    @Before("@annotation(dataScope)")
    public void before(JoinPoint point, DataScope dataScope) {
        User user = SecurityUtils.getUser();
        StringBuilder sql = new StringBuilder();

        // 根据用户数据范围构建 SQL
        switch (user.getDataScope()) {
            case ALL:
                // 全部数据权限
                break;
            case DEPT:
                // 部门数据权限
                sql.append(String.format(" AND %s.dept_id = %d",
                    dataScope.deptAlias(), user.getDeptId()));
                break;
            case DEPT_AND_CHILD:
                // 部门及子部门
                sql.append(String.format(" AND %s.dept_id IN (SELECT id FROM sys_dept WHERE FIND_IN_SET(%d, ancestors))",
                    dataScope.deptAlias(), user.getDeptId()));
                break;
            case SELF:
                // 仅本人
                sql.append(String.format(" AND %s.user_id = %d",
                    dataScope.userAlias(), user.getId()));
                break;
        }

        DataScopeContext.set(sql.toString());
    }
}
```

## 三、数据安全

### 3.1 数据脱敏

```java
// 脱敏注解
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Sensitive {
    SensitiveType type();
}

public enum SensitiveType {
    PHONE,      // 手机号: 138****1234
    ID_CARD,    // 身份证: 110***********1234
    BANK_CARD,  // 银行卡: 6222************1234
    EMAIL,      // 邮箱: t***@example.com
    NAME,       // 姓名: 张*
    ADDRESS     // 地址: 北京市***
}

// 脱敏序列化器
public class SensitiveSerializer extends JsonSerializer<String> {

    @Override
    public void serialize(String value, JsonGenerator gen, SerializerProvider provider) throws IOException {
        Sensitive sensitive = // 获取注解
        String masked = SensitiveUtils.mask(value, sensitive.type());
        gen.writeString(masked);
    }
}

// 使用
@Data
public class UserVO {
    private Long id;
    private String username;

    @Sensitive(type = SensitiveType.PHONE)
    private String phone;

    @Sensitive(type = SensitiveType.ID_CARD)
    private String idCard;
}
```

### 3.2 字段加密

```java
// 加密字段注解
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Encrypted {
}

// MyBatis 类型处理器
@MappedTypes(String.class)
public class EncryptedTypeHandler extends BaseTypeHandler<String> {

    @Autowired
    private EncryptionService encryptionService;

    @Override
    public void setNonNullParameter(PreparedStatement ps, int i, String parameter, JdbcType jdbcType) throws SQLException {
        ps.setString(i, encryptionService.encrypt(parameter));
    }

    @Override
    public String getNullableResult(ResultSet rs, String columnName) throws SQLException {
        String value = rs.getString(columnName);
        return value != null ? encryptionService.decrypt(value) : null;
    }
}

// 加密服务
@Service
public class EncryptionService {

    @Value("${encryption.key}")
    private String key;

    public String encrypt(String plaintext) {
        return AESUtils.encrypt(plaintext, key);
    }

    public String decrypt(String ciphertext) {
        return AESUtils.decrypt(ciphertext, key);
    }
}
```

### 3.3 接口签名

```java
// 接口签名验证
@Component
public class SignatureFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain) {
        String timestamp = request.getHeader("X-Timestamp");
        String nonce = request.getHeader("X-Nonce");
        String signature = request.getHeader("X-Signature");

        // 1. 验证时间戳（防重放）
        if (Math.abs(System.currentTimeMillis() - Long.parseLong(timestamp)) > 300000) {
            throw new BizException("请求已过期");
        }

        // 2. 验证 nonce（防重放）
        if (redisTemplate.hasKey("nonce:" + nonce)) {
            throw new BizException("重复请求");
        }
        redisTemplate.opsForValue().set("nonce:" + nonce, "1", 5, TimeUnit.MINUTES);

        // 3. 验证签名
        String expectedSignature = SignatureUtils.sign(timestamp, nonce, getBody(request), secretKey);
        if (!expectedSignature.equals(signature)) {
            throw new BizException("签名验证失败");
        }

        chain.doFilter(request, response);
    }
}
```

## 四、审计日志

```java
// 审计日志注解
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface AuditLog {
    String module();
    String action();
}

// 审计日志切面
@Aspect
@Component
public class AuditLogAspect {

    @Autowired
    private AuditLogService auditLogService;

    @Around("@annotation(auditLog)")
    public Object around(ProceedingJoinPoint pjp, AuditLog auditLog) throws Throwable {
        long start = System.currentTimeMillis();
        Object result = null;
        String status = "SUCCESS";
        String errorMsg = null;

        try {
            result = pjp.proceed();
            return result;
        } catch (Exception e) {
            status = "FAILED";
            errorMsg = e.getMessage();
            throw e;
        } finally {
            // 记录审计日志
            AuditLogEntity log = AuditLogEntity.builder()
                .module(auditLog.module())
                .action(auditLog.action())
                .userId(UserContext.getUserId())
                .username(UserContext.getUsername())
                .tenantId(TenantContext.getTenantId())
                .clientIp(RequestContext.getClientIp())
                .requestUri(RequestContext.getUri())
                .requestMethod(RequestContext.getMethod())
                .requestParams(JsonUtils.toJson(pjp.getArgs()))
                .responseResult(status.equals("SUCCESS") ? JsonUtils.toJson(result) : null)
                .status(status)
                .errorMsg(errorMsg)
                .duration(System.currentTimeMillis() - start)
                .operateTime(LocalDateTime.now())
                .build();

            auditLogService.saveAsync(log);
        }
    }
}

// 使用
@AuditLog(module = "用户管理", action = "删除用户")
public void deleteUser(Long userId) {
    // ...
}
```
