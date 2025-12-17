# 05 - 业务支撑层设计

## 一、业务支撑架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              业务支撑层架构                                          │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           API Gateway (APISIX)                               │   │
│  │  路由转发 │ 认证授权 │ 限流熔断 │ 协议转换 │ 日志审计                        │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌───────────────────────────────────┼───────────────────────────────────────────┐ │
│  │                                   ▼                                           │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │ │
│  │  │ 认证服务    │  │ 用户服务    │  │ 权限服务    │  │ 租户服务    │          │ │
│  │  │ auth-svc   │  │ user-svc   │  │ perm-svc   │  │ tenant-svc │          │ │
│  │  │ (OAuth2)   │  │ (CRUD)     │  │ (RBAC)     │  │ (多租户)   │          │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘          │ │
│  │                                                                               │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │ │
│  │  │ 消息服务    │  │ 文件服务    │  │ 通知服务    │  │ 字典服务    │          │ │
│  │  │ msg-svc    │  │ file-svc   │  │ notify-svc │  │ dict-svc   │          │ │
│  │  │ (异步消息) │  │ (Go/MinIO) │  │ (多渠道)   │  │ (配置)     │          │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘          │ │
│  │                                                                               │ │
│  │                         平台基础服务层                                        │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、认证服务 (auth-service)

### 2.1 功能概述

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              认证服务功能                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  登录方式:                       Token管理:                 安全特性:               │
│  ├── 账号密码                    ├── JWT 生成/验证          ├── 多端踢出            │
│  ├── 手机验证码                  ├── Token 续期             ├── 登录IP限制          │
│  ├── 企业微信扫码                ├── Token 注销             ├── 密码策略            │
│  ├── 飞书扫码                    ├── 黑名单管理             ├── 登录日志            │
│  ├── 钉钉扫码                    └── 多端登录控制           ├── 异常登录检测        │
│  └── LDAP/AD                                                └── 验证码防爆破        │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 核心接口

```java
// 认证控制器
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @Autowired
    private AuthService authService;

    /**
     * 账号密码登录
     */
    @PostMapping("/login")
    public R<TokenVO> login(@RequestBody @Valid LoginDTO dto) {
        return R.ok(authService.login(dto));
    }

    /**
     * 手机验证码登录
     */
    @PostMapping("/login/sms")
    public R<TokenVO> loginBySms(@RequestBody @Valid SmsLoginDTO dto) {
        return R.ok(authService.loginBySms(dto));
    }

    /**
     * OAuth2 第三方登录
     */
    @GetMapping("/oauth2/{provider}")
    public R<String> oauth2Login(@PathVariable String provider,
                                  @RequestParam String redirectUri) {
        return R.ok(authService.getOAuth2Url(provider, redirectUri));
    }

    @GetMapping("/oauth2/{provider}/callback")
    public R<TokenVO> oauth2Callback(@PathVariable String provider,
                                      @RequestParam String code,
                                      @RequestParam String state) {
        return R.ok(authService.oauth2Callback(provider, code, state));
    }

    /**
     * 刷新Token
     */
    @PostMapping("/refresh")
    public R<TokenVO> refresh(@RequestHeader("X-Refresh-Token") String refreshToken) {
        return R.ok(authService.refreshToken(refreshToken));
    }

    /**
     * 退出登录
     */
    @PostMapping("/logout")
    public R<Void> logout(@RequestHeader("Authorization") String token) {
        authService.logout(token);
        return R.ok();
    }
}
```

### 2.3 Token 设计

```java
// JWT Token 结构
@Data
public class JwtPayload {
    private Long userId;           // 用户ID
    private String username;       // 用户名
    private Long tenantId;         // 租户ID
    private String tenantCode;     // 租户编码
    private List<String> roles;    // 角色列表
    private String clientType;     // 客户端类型: web/app/mini
    private String deviceId;       // 设备标识
    private Long iat;              // 签发时间
    private Long exp;              // 过期时间
}

// Token 服务
@Service
public class TokenService {

    @Value("${jwt.secret}")
    private String jwtSecret;

    @Value("${jwt.access-token-expire:7200}")
    private long accessTokenExpire;

    @Value("${jwt.refresh-token-expire:604800}")
    private long refreshTokenExpire;

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    /**
     * 生成 Token 对
     */
    public TokenVO createToken(User user, String clientType, String deviceId) {
        long now = System.currentTimeMillis();

        // 构建 JWT Payload
        JwtPayload payload = JwtPayload.builder()
            .userId(user.getId())
            .username(user.getUsername())
            .tenantId(user.getTenantId())
            .tenantCode(user.getTenantCode())
            .roles(user.getRoles())
            .clientType(clientType)
            .deviceId(deviceId)
            .iat(now)
            .exp(now + accessTokenExpire * 1000)
            .build();

        // 生成 AccessToken
        String accessToken = Jwts.builder()
            .setClaims(BeanUtils.toMap(payload))
            .signWith(SignatureAlgorithm.HS256, jwtSecret)
            .compact();

        // 生成 RefreshToken
        String refreshToken = UUID.randomUUID().toString().replace("-", "");

        // 存储 RefreshToken 到 Redis
        String refreshKey = String.format("auth:refresh:%s:%s", user.getId(), refreshToken);
        redisTemplate.opsForValue().set(refreshKey, payload, refreshTokenExpire, TimeUnit.SECONDS);

        // 记录用户登录设备 (用于多端管理)
        String deviceKey = String.format("auth:device:%s:%s", user.getId(), deviceId);
        redisTemplate.opsForValue().set(deviceKey, accessToken, accessTokenExpire, TimeUnit.SECONDS);

        return TokenVO.builder()
            .accessToken(accessToken)
            .refreshToken(refreshToken)
            .expiresIn(accessTokenExpire)
            .tokenType("Bearer")
            .build();
    }

    /**
     * 踢出其他设备
     */
    public void kickOtherDevices(Long userId, String currentDeviceId) {
        String pattern = String.format("auth:device:%s:*", userId);
        Set<String> keys = redisTemplate.keys(pattern);

        for (String key : keys) {
            if (!key.endsWith(currentDeviceId)) {
                String token = (String) redisTemplate.opsForValue().get(key);
                if (token != null) {
                    // 加入黑名单
                    addToBlacklist(token);
                }
                redisTemplate.delete(key);
            }
        }
    }
}
```

## 三、用户服务 (user-service)

### 3.1 数据模型

```sql
-- 用户表
CREATE TABLE sys_user (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL COMMENT '用户名',
    password VARCHAR(100) NOT NULL COMMENT '密码',
    nickname VARCHAR(50) COMMENT '昵称',
    email VARCHAR(100) COMMENT '邮箱',
    phone VARCHAR(20) COMMENT '手机号',
    avatar VARCHAR(255) COMMENT '头像',
    gender TINYINT DEFAULT 0 COMMENT '性别: 0未知 1男 2女',
    status TINYINT DEFAULT 1 COMMENT '状态: 0禁用 1正常',
    dept_id BIGINT COMMENT '部门ID',
    tenant_id BIGINT NOT NULL COMMENT '租户ID',
    last_login_time DATETIME COMMENT '最后登录时间',
    last_login_ip VARCHAR(50) COMMENT '最后登录IP',
    pwd_update_time DATETIME COMMENT '密码修改时间',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    create_by BIGINT,
    update_by BIGINT,
    deleted TINYINT DEFAULT 0,
    UNIQUE KEY uk_username_tenant (username, tenant_id),
    KEY idx_tenant (tenant_id),
    KEY idx_dept (dept_id)
) COMMENT '用户表';

-- 部门表
CREATE TABLE sys_dept (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    parent_id BIGINT DEFAULT 0 COMMENT '父部门ID',
    ancestors VARCHAR(500) COMMENT '祖级列表',
    dept_name VARCHAR(100) NOT NULL COMMENT '部门名称',
    dept_code VARCHAR(50) COMMENT '部门编码',
    leader VARCHAR(50) COMMENT '负责人',
    phone VARCHAR(20) COMMENT '联系电话',
    email VARCHAR(100) COMMENT '邮箱',
    sort INT DEFAULT 0 COMMENT '排序',
    status TINYINT DEFAULT 1 COMMENT '状态',
    tenant_id BIGINT NOT NULL COMMENT '租户ID',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0,
    KEY idx_parent (parent_id),
    KEY idx_tenant (tenant_id)
) COMMENT '部门表';

-- 岗位表
CREATE TABLE sys_post (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    post_code VARCHAR(50) NOT NULL COMMENT '岗位编码',
    post_name VARCHAR(100) NOT NULL COMMENT '岗位名称',
    sort INT DEFAULT 0 COMMENT '排序',
    status TINYINT DEFAULT 1 COMMENT '状态',
    tenant_id BIGINT NOT NULL COMMENT '租户ID',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0,
    UNIQUE KEY uk_code_tenant (post_code, tenant_id)
) COMMENT '岗位表';

-- 用户岗位关联表
CREATE TABLE sys_user_post (
    user_id BIGINT NOT NULL,
    post_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, post_id)
) COMMENT '用户岗位关联表';
```

### 3.2 用户服务接口

```java
@RestController
@RequestMapping("/api/users")
public class UserController {

    @Autowired
    private UserService userService;

    /**
     * 获取当前用户信息
     */
    @GetMapping("/current")
    public R<UserVO> getCurrentUser() {
        return R.ok(userService.getCurrentUser());
    }

    /**
     * 分页查询用户
     */
    @GetMapping
    @PreAuthorize("hasPermission('user:list')")
    public R<PageResult<UserVO>> page(UserQueryDTO query) {
        return R.ok(userService.page(query));
    }

    /**
     * 创建用户
     */
    @PostMapping
    @PreAuthorize("hasPermission('user:add')")
    @AuditLog(module = "用户管理", action = "新增用户")
    public R<Long> create(@RequestBody @Valid UserCreateDTO dto) {
        return R.ok(userService.create(dto));
    }

    /**
     * 更新用户
     */
    @PutMapping("/{id}")
    @PreAuthorize("hasPermission('user:edit')")
    @AuditLog(module = "用户管理", action = "修改用户")
    public R<Void> update(@PathVariable Long id, @RequestBody @Valid UserUpdateDTO dto) {
        userService.update(id, dto);
        return R.ok();
    }

    /**
     * 重置密码
     */
    @PutMapping("/{id}/password/reset")
    @PreAuthorize("hasPermission('user:resetPwd')")
    @AuditLog(module = "用户管理", action = "重置密码")
    public R<Void> resetPassword(@PathVariable Long id) {
        userService.resetPassword(id);
        return R.ok();
    }

    /**
     * 修改密码
     */
    @PutMapping("/password")
    @AuditLog(module = "用户管理", action = "修改密码")
    public R<Void> changePassword(@RequestBody @Valid ChangePasswordDTO dto) {
        userService.changePassword(dto);
        return R.ok();
    }

    /**
     * 导入用户
     */
    @PostMapping("/import")
    @PreAuthorize("hasPermission('user:import')")
    @AuditLog(module = "用户管理", action = "导入用户")
    public R<ImportResult> importUsers(@RequestParam("file") MultipartFile file) {
        return R.ok(userService.importUsers(file));
    }

    /**
     * 导出用户
     */
    @GetMapping("/export")
    @PreAuthorize("hasPermission('user:export')")
    @AuditLog(module = "用户管理", action = "导出用户")
    public void exportUsers(UserQueryDTO query, HttpServletResponse response) {
        userService.exportUsers(query, response);
    }
}
```

## 四、权限服务 (permission-service)

### 4.1 RBAC 模型

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              RBAC 权限模型                                           │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────┐         ┌─────────┐         ┌─────────┐                               │
│  │  User   │ ──N:M── │  Role   │ ──N:M── │  Perm   │                               │
│  │  用户   │         │  角色   │         │  权限   │                               │
│  └─────────┘         └─────────┘         └─────────┘                               │
│                            │                                                        │
│                            │                                                        │
│                            ▼                                                        │
│                      ┌─────────┐                                                    │
│                      │  Menu   │                                                    │
│                      │  菜单   │                                                    │
│                      └─────────┘                                                    │
│                                                                                     │
│  权限类型:                                                                          │
│  ├── menu   - 菜单权限 (前端路由)                                                   │
│  ├── button - 按钮权限 (页面操作)                                                   │
│  └── api    - 接口权限 (后端API)                                                    │
│                                                                                     │
│  数据权限:                                                                          │
│  ├── ALL          - 全部数据                                                        │
│  ├── DEPT         - 本部门数据                                                      │
│  ├── DEPT_CHILD   - 本部门及子部门                                                  │
│  ├── SELF         - 仅本人数据                                                      │
│  └── CUSTOM       - 自定义数据权限                                                  │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 数据模型

```sql
-- 角色表
CREATE TABLE sys_role (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    role_code VARCHAR(50) NOT NULL COMMENT '角色编码',
    role_name VARCHAR(100) NOT NULL COMMENT '角色名称',
    data_scope TINYINT DEFAULT 1 COMMENT '数据范围: 1全部 2本部门 3本部门及子部门 4仅本人 5自定义',
    sort INT DEFAULT 0 COMMENT '排序',
    status TINYINT DEFAULT 1 COMMENT '状态',
    remark VARCHAR(500) COMMENT '备注',
    tenant_id BIGINT NOT NULL COMMENT '租户ID',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0,
    UNIQUE KEY uk_code_tenant (role_code, tenant_id)
) COMMENT '角色表';

-- 菜单/权限表
CREATE TABLE sys_menu (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    parent_id BIGINT DEFAULT 0 COMMENT '父菜单ID',
    menu_name VARCHAR(100) NOT NULL COMMENT '菜单名称',
    menu_type CHAR(1) NOT NULL COMMENT '类型: M目录 C菜单 B按钮',
    path VARCHAR(200) COMMENT '路由地址',
    component VARCHAR(200) COMMENT '组件路径',
    perms VARCHAR(100) COMMENT '权限标识',
    icon VARCHAR(100) COMMENT '图标',
    sort INT DEFAULT 0 COMMENT '排序',
    visible TINYINT DEFAULT 1 COMMENT '是否可见',
    status TINYINT DEFAULT 1 COMMENT '状态',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_parent (parent_id)
) COMMENT '菜单权限表';

-- 用户角色关联
CREATE TABLE sys_user_role (
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, role_id)
) COMMENT '用户角色关联表';

-- 角色菜单关联
CREATE TABLE sys_role_menu (
    role_id BIGINT NOT NULL,
    menu_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, menu_id)
) COMMENT '角色菜单关联表';

-- 角色部门关联 (自定义数据权限)
CREATE TABLE sys_role_dept (
    role_id BIGINT NOT NULL,
    dept_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, dept_id)
) COMMENT '角色部门关联表';
```

### 4.3 权限校验

```java
// 权限校验切面
@Aspect
@Component
public class PermissionAspect {

    @Autowired
    private PermissionService permissionService;

    @Before("@annotation(preAuthorize)")
    public void checkPermission(JoinPoint point, PreAuthorize preAuthorize) {
        String expression = preAuthorize.value();

        // 解析权限表达式
        if (expression.startsWith("hasPermission")) {
            String perm = extractPermission(expression);
            if (!permissionService.hasPermission(perm)) {
                throw new BizException(ResultCode.FORBIDDEN, "无操作权限: " + perm);
            }
        } else if (expression.startsWith("hasRole")) {
            String role = extractRole(expression);
            if (!permissionService.hasRole(role)) {
                throw new BizException(ResultCode.FORBIDDEN, "无角色权限: " + role);
            }
        }
    }
}

// 权限服务
@Service
public class PermissionService {

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    /**
     * 获取用户权限列表 (带缓存)
     */
    @Cacheable(value = "user:permissions", key = "#userId")
    public Set<String> getUserPermissions(Long userId) {
        return permissionMapper.selectPermissionsByUserId(userId);
    }

    /**
     * 检查权限
     */
    public boolean hasPermission(String permission) {
        Long userId = UserContext.getUserId();
        Set<String> permissions = getUserPermissions(userId);

        // 超级管理员拥有所有权限
        if (permissions.contains("*:*:*")) {
            return true;
        }

        return permissions.contains(permission);
    }

    /**
     * 清除权限缓存
     */
    @CacheEvict(value = "user:permissions", key = "#userId")
    public void clearPermissionCache(Long userId) {
        // 缓存自动清除
    }

    /**
     * 批量清除权限缓存 (角色变更时)
     */
    public void clearPermissionCacheByRole(Long roleId) {
        List<Long> userIds = userRoleMapper.selectUserIdsByRoleId(roleId);
        for (Long userId : userIds) {
            clearPermissionCache(userId);
        }
    }
}
```

## 五、租户服务 (tenant-service)

### 5.1 多租户架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              多租户架构                                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  租户隔离策略:                                                                       │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                             │   │
│  │  方案A: 共享数据库 + 租户字段 (tenant_id)   ← 当前采用                       │   │
│  │  ├── 优点: 资源利用率高，维护成本低                                         │   │
│  │  └── 缺点: 数据隔离依赖代码保证                                             │   │
│  │                                                                             │   │
│  │  方案B: 独立Schema                                                          │   │
│  │  ├── 优点: 隔离性好                                                         │   │
│  │  └── 缺点: Schema 数量受限                                                  │   │
│  │                                                                             │   │
│  │  方案C: 独立数据库                                                          │   │
│  │  ├── 优点: 完全隔离                                                         │   │
│  │  └── 缺点: 资源成本高                                                       │   │
│  │                                                                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  租户数据流:                                                                        │
│  ┌────────────────────────────────────────────────────────────────────────────┐    │
│  │                                                                            │    │
│  │  Request → Token解析 → TenantContext → MyBatis拦截器 → SQL自动加tenant_id  │    │
│  │                                                                            │    │
│  └────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 数据模型

```sql
-- 租户表
CREATE TABLE sys_tenant (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    tenant_code VARCHAR(50) NOT NULL UNIQUE COMMENT '租户编码',
    tenant_name VARCHAR(100) NOT NULL COMMENT '租户名称',
    contact_name VARCHAR(50) COMMENT '联系人',
    contact_phone VARCHAR(20) COMMENT '联系电话',
    contact_email VARCHAR(100) COMMENT '联系邮箱',
    domain VARCHAR(100) COMMENT '绑定域名',
    logo VARCHAR(255) COMMENT 'Logo',
    expire_time DATETIME COMMENT '过期时间',
    account_limit INT DEFAULT -1 COMMENT '账号数量限制 -1不限',
    status TINYINT DEFAULT 1 COMMENT '状态: 0禁用 1正常 2过期',
    remark VARCHAR(500) COMMENT '备注',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0
) COMMENT '租户表';

-- 租户套餐表
CREATE TABLE sys_tenant_package (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    package_name VARCHAR(100) NOT NULL COMMENT '套餐名称',
    menu_ids TEXT COMMENT '关联菜单ID',
    status TINYINT DEFAULT 1 COMMENT '状态',
    remark VARCHAR(500) COMMENT '备注',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted TINYINT DEFAULT 0
) COMMENT '租户套餐表';

-- 租户套餐关联
ALTER TABLE sys_tenant ADD COLUMN package_id BIGINT COMMENT '套餐ID';
```

### 5.3 租户上下文

```java
// 租户上下文
public class TenantContext {

    private static final ThreadLocal<Long> TENANT_ID = new TransmittableThreadLocal<>();
    private static final ThreadLocal<String> TENANT_CODE = new TransmittableThreadLocal<>();

    public static void setTenantId(Long tenantId) {
        TENANT_ID.set(tenantId);
    }

    public static Long getTenantId() {
        return TENANT_ID.get();
    }

    public static void setTenantCode(String tenantCode) {
        TENANT_CODE.set(tenantCode);
    }

    public static String getTenantCode() {
        return TENANT_CODE.get();
    }

    public static void clear() {
        TENANT_ID.remove();
        TENANT_CODE.remove();
    }
}

// MyBatis 租户拦截器
@Intercepts({
    @Signature(type = Executor.class, method = "update", args = {MappedStatement.class, Object.class}),
    @Signature(type = Executor.class, method = "query", args = {MappedStatement.class, Object.class, RowBounds.class, ResultHandler.class})
})
@Component
public class TenantInterceptor implements Interceptor {

    @Autowired
    private TenantProperties tenantProperties;

    @Override
    public Object intercept(Invocation invocation) throws Throwable {
        MappedStatement ms = (MappedStatement) invocation.getArgs()[0];

        // 检查是否需要租户过滤
        if (shouldApplyTenant(ms)) {
            Object parameter = invocation.getArgs()[1];
            BoundSql boundSql = ms.getBoundSql(parameter);
            String sql = boundSql.getSql();

            // 添加租户条件
            String newSql = addTenantCondition(sql);

            // 替换 SQL
            Field field = boundSql.getClass().getDeclaredField("sql");
            field.setAccessible(true);
            field.set(boundSql, newSql);
        }

        return invocation.proceed();
    }

    private boolean shouldApplyTenant(MappedStatement ms) {
        // 检查是否在忽略列表中
        String id = ms.getId();
        return !tenantProperties.getIgnoreTables().stream()
            .anyMatch(table -> id.contains(table));
    }

    private String addTenantCondition(String sql) {
        Long tenantId = TenantContext.getTenantId();
        if (tenantId == null) {
            return sql;
        }

        // 使用 JSqlParser 解析并添加条件
        try {
            Statement statement = CCJSqlParserUtil.parse(sql);
            if (statement instanceof Select) {
                Select select = (Select) statement;
                // 添加 tenant_id 条件
                // ...
            }
            return statement.toString();
        } catch (Exception e) {
            return sql;
        }
    }
}
```

## 六、消息服务 (message-service)

### 6.1 消息架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              消息服务架构                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  消息类型:                                                                          │
│  ├── 系统通知 (system)    - 系统级公告、维护通知                                    │
│  ├── 业务消息 (business)  - 审批、任务、提醒                                        │
│  ├── 站内信 (inbox)       - 用户间消息                                              │
│  └── 公告 (announce)      - 全员公告                                                │
│                                                                                     │
│  消息流程:                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                             │   │
│  │  Producer ──▶ RocketMQ ──▶ Consumer ──▶ 消息存储 ──▶ WebSocket 推送        │   │
│  │                              │                          │                   │   │
│  │                              │                          ▼                   │   │
│  │                              └──▶ 离线存储 ──▶ 登录后拉取                   │   │
│  │                                                                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 消息服务

```java
// 消息发送服务
@Service
public class MessageService {

    @Autowired
    private RocketMQTemplate rocketMQTemplate;

    @Autowired
    private MessageMapper messageMapper;

    @Autowired
    private WebSocketService webSocketService;

    /**
     * 发送消息
     */
    public void sendMessage(MessageDTO dto) {
        // 1. 存储消息
        Message message = Message.builder()
            .messageType(dto.getMessageType())
            .title(dto.getTitle())
            .content(dto.getContent())
            .senderId(UserContext.getUserId())
            .tenantId(TenantContext.getTenantId())
            .createTime(LocalDateTime.now())
            .build();
        messageMapper.insert(message);

        // 2. 创建用户消息关联
        List<MessageUser> messageUsers = dto.getReceiverIds().stream()
            .map(userId -> MessageUser.builder()
                .messageId(message.getId())
                .userId(userId)
                .readStatus(0)
                .createTime(LocalDateTime.now())
                .build())
            .collect(Collectors.toList());
        messageUserMapper.batchInsert(messageUsers);

        // 3. 发送到 MQ 进行异步推送
        rocketMQTemplate.asyncSend("message-topic", message, new SendCallback() {
            @Override
            public void onSuccess(SendResult result) {
                log.info("消息发送成功: {}", result.getMsgId());
            }

            @Override
            public void onException(Throwable e) {
                log.error("消息发送失败", e);
            }
        });
    }

    /**
     * 获取未读消息数
     */
    public Map<String, Integer> getUnreadCount(Long userId) {
        return messageMapper.selectUnreadCountByType(userId);
    }

    /**
     * 标记已读
     */
    public void markAsRead(Long userId, List<Long> messageIds) {
        messageUserMapper.updateReadStatus(userId, messageIds, 1);
    }
}

// WebSocket 消息推送
@ServerEndpoint("/ws/message/{token}")
@Component
public class MessageWebSocket {

    private static final Map<Long, Session> USER_SESSIONS = new ConcurrentHashMap<>();

    @OnOpen
    public void onOpen(Session session, @PathParam("token") String token) {
        // 解析 Token 获取用户ID
        Long userId = TokenUtils.getUserId(token);
        if (userId != null) {
            USER_SESSIONS.put(userId, session);
            log.info("用户 {} WebSocket 连接成功", userId);
        }
    }

    @OnClose
    public void onClose(Session session) {
        USER_SESSIONS.entrySet().removeIf(entry -> entry.getValue().equals(session));
    }

    /**
     * 推送消息给指定用户
     */
    public static void pushMessage(Long userId, String message) {
        Session session = USER_SESSIONS.get(userId);
        if (session != null && session.isOpen()) {
            try {
                session.getBasicRemote().sendText(message);
            } catch (IOException e) {
                log.error("WebSocket 推送失败", e);
            }
        }
    }

    /**
     * 广播消息
     */
    public static void broadcast(String message) {
        USER_SESSIONS.values().forEach(session -> {
            if (session.isOpen()) {
                try {
                    session.getAsyncRemote().sendText(message);
                } catch (Exception e) {
                    log.error("WebSocket 广播失败", e);
                }
            }
        });
    }
}
```

## 七、文件服务 (file-service) - Go 实现

### 7.1 文件服务架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              文件服务架构                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  功能特性:                                                                          │
│  ├── 文件上传 (普通/分片/断点续传)                                                  │
│  ├── 文件下载 (直接/流式/断点续传)                                                  │
│  ├── 图片处理 (缩略图/水印/裁剪)                                                    │
│  ├── 文件预览 (PDF/Office/图片)                                                     │
│  └── 存储适配 (MinIO/S3/本地)                                                       │
│                                                                                     │
│  存储策略:                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                             │   │
│  │  小文件 (< 5MB)     ──▶  直接上传                                           │   │
│  │  大文件 (>= 5MB)    ──▶  分片上传 (每片 5MB)                                 │   │
│  │  临时文件           ──▶  7天后自动清理                                       │   │
│  │  永久文件           ──▶  按业务模块分桶存储                                  │   │
│  │                                                                             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Go 文件服务实现

```go
// file-service/internal/handler/file_handler.go
package handler

import (
    "crypto/md5"
    "fmt"
    "io"
    "net/http"
    "path/filepath"
    "strconv"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/minio/minio-go/v7"
)

type FileHandler struct {
    minioClient *minio.Client
    bucketName  string
}

// 上传文件
func (h *FileHandler) Upload(c *gin.Context) {
    file, header, err := c.Request.FormFile("file")
    if err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "文件上传失败"})
        return
    }
    defer file.Close()

    // 生成文件路径: /年/月/日/md5.ext
    ext := filepath.Ext(header.Filename)
    hash := md5.New()
    io.Copy(hash, file)
    file.Seek(0, 0)

    now := time.Now()
    objectName := fmt.Sprintf("%d/%02d/%02d/%x%s",
        now.Year(), now.Month(), now.Day(), hash.Sum(nil), ext)

    // 上传到 MinIO
    _, err = h.minioClient.PutObject(c, h.bucketName, objectName, file, header.Size,
        minio.PutObjectOptions{
            ContentType: header.Header.Get("Content-Type"),
        })
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "存储失败"})
        return
    }

    // 返回文件信息
    c.JSON(http.StatusOK, gin.H{
        "code": 0,
        "data": gin.H{
            "url":      fmt.Sprintf("/files/%s/%s", h.bucketName, objectName),
            "name":     header.Filename,
            "size":     header.Size,
            "mimeType": header.Header.Get("Content-Type"),
        },
    })
}

// 分片上传初始化
func (h *FileHandler) InitMultipartUpload(c *gin.Context) {
    var req struct {
        Filename string `json:"filename"`
        FileSize int64  `json:"fileSize"`
        ChunkSize int64 `json:"chunkSize"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    // 计算分片数量
    chunkCount := (req.FileSize + req.ChunkSize - 1) / req.ChunkSize

    // 生成上传ID
    uploadId := generateUploadId()

    // 存储上传任务信息到 Redis
    // ...

    c.JSON(http.StatusOK, gin.H{
        "code": 0,
        "data": gin.H{
            "uploadId":   uploadId,
            "chunkCount": chunkCount,
            "chunkSize":  req.ChunkSize,
        },
    })
}

// 上传分片
func (h *FileHandler) UploadChunk(c *gin.Context) {
    uploadId := c.PostForm("uploadId")
    chunkIndex, _ := strconv.Atoi(c.PostForm("chunkIndex"))

    file, _, err := c.Request.FormFile("chunk")
    if err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    defer file.Close()

    // 存储分片
    chunkKey := fmt.Sprintf("chunks/%s/%d", uploadId, chunkIndex)
    _, err = h.minioClient.PutObject(c, "temp", chunkKey, file, -1, minio.PutObjectOptions{})
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "分片上传失败"})
        return
    }

    c.JSON(http.StatusOK, gin.H{"code": 0, "message": "分片上传成功"})
}

// 合并分片
func (h *FileHandler) MergeChunks(c *gin.Context) {
    var req struct {
        UploadId   string `json:"uploadId"`
        Filename   string `json:"filename"`
        ChunkCount int    `json:"chunkCount"`
    }
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    // 合并分片
    sources := make([]minio.CopySrcOptions, req.ChunkCount)
    for i := 0; i < req.ChunkCount; i++ {
        sources[i] = minio.CopySrcOptions{
            Bucket: "temp",
            Object: fmt.Sprintf("chunks/%s/%d", req.UploadId, i),
        }
    }

    // 生成目标路径
    ext := filepath.Ext(req.Filename)
    now := time.Now()
    objectName := fmt.Sprintf("%d/%02d/%02d/%s%s",
        now.Year(), now.Month(), now.Day(), req.UploadId, ext)

    // 执行合并
    _, err := h.minioClient.ComposeObject(c, minio.CopyDestOptions{
        Bucket: h.bucketName,
        Object: objectName,
    }, sources...)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "合并失败"})
        return
    }

    // 清理分片
    go h.cleanupChunks(req.UploadId, req.ChunkCount)

    c.JSON(http.StatusOK, gin.H{
        "code": 0,
        "data": gin.H{
            "url": fmt.Sprintf("/files/%s/%s", h.bucketName, objectName),
        },
    })
}

// 下载文件
func (h *FileHandler) Download(c *gin.Context) {
    bucket := c.Param("bucket")
    objectName := c.Param("object")

    // 获取文件信息
    stat, err := h.minioClient.StatObject(c, bucket, objectName, minio.StatObjectOptions{})
    if err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "文件不存在"})
        return
    }

    // 支持断点续传
    rangeHeader := c.GetHeader("Range")
    if rangeHeader != "" {
        // 解析 Range 头并返回部分内容
        // ...
    }

    // 获取文件流
    object, err := h.minioClient.GetObject(c, bucket, objectName, minio.GetObjectOptions{})
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "下载失败"})
        return
    }
    defer object.Close()

    // 设置响应头
    c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", filepath.Base(objectName)))
    c.Header("Content-Type", stat.ContentType)
    c.Header("Content-Length", strconv.FormatInt(stat.Size, 10))

    // 流式输出
    io.Copy(c.Writer, object)
}
```

## 八、通知服务 (notification-service)

### 8.1 多渠道通知

```java
// 通知服务
@Service
public class NotificationService {

    @Autowired
    private Map<String, NotificationChannel> channels;

    /**
     * 发送通知
     */
    public void send(NotificationDTO dto) {
        for (String channelType : dto.getChannels()) {
            NotificationChannel channel = channels.get(channelType);
            if (channel != null) {
                try {
                    channel.send(dto);
                } catch (Exception e) {
                    log.error("通知发送失败: channel={}, error={}", channelType, e.getMessage());
                }
            }
        }
    }
}

// 通知渠道接口
public interface NotificationChannel {
    void send(NotificationDTO dto);
}

// 飞书通知
@Component("feishu")
public class FeishuNotificationChannel implements NotificationChannel {

    @Value("${notification.feishu.webhook}")
    private String webhook;

    @Override
    public void send(NotificationDTO dto) {
        Map<String, Object> message = new HashMap<>();
        message.put("msg_type", "interactive");
        message.put("card", buildCard(dto));

        HttpUtil.post(webhook, JsonUtils.toJson(message));
    }

    private Map<String, Object> buildCard(NotificationDTO dto) {
        // 构建飞书卡片消息
        return Map.of(
            "header", Map.of(
                "title", Map.of("content", dto.getTitle(), "tag", "plain_text"),
                "template", getColorTemplate(dto.getLevel())
            ),
            "elements", List.of(
                Map.of("tag", "div", "text", Map.of("content", dto.getContent(), "tag", "lark_md"))
            )
        );
    }
}

// 企业微信通知
@Component("wecom")
public class WeComNotificationChannel implements NotificationChannel {

    @Value("${notification.wecom.webhook}")
    private String webhook;

    @Override
    public void send(NotificationDTO dto) {
        Map<String, Object> message = Map.of(
            "msgtype", "markdown",
            "markdown", Map.of(
                "content", String.format("## %s\n%s", dto.getTitle(), dto.getContent())
            )
        );

        HttpUtil.post(webhook, JsonUtils.toJson(message));
    }
}

// 短信通知
@Component("sms")
public class SmsNotificationChannel implements NotificationChannel {

    @Autowired
    private SmsClient smsClient;

    @Override
    public void send(NotificationDTO dto) {
        for (String phone : dto.getPhones()) {
            smsClient.send(phone, dto.getTemplateCode(), dto.getTemplateParams());
        }
    }
}

// 邮件通知
@Component("email")
public class EmailNotificationChannel implements NotificationChannel {

    @Autowired
    private JavaMailSender mailSender;

    @Override
    public void send(NotificationDTO dto) {
        MimeMessage message = mailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true);

        helper.setTo(dto.getEmails().toArray(new String[0]));
        helper.setSubject(dto.getTitle());
        helper.setText(dto.getContent(), true);

        mailSender.send(message);
    }
}
```

## 九、字典服务 (dict-service)

### 9.1 数据模型

```sql
-- 字典类型表
CREATE TABLE sys_dict_type (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    dict_type VARCHAR(100) NOT NULL COMMENT '字典类型',
    dict_name VARCHAR(100) NOT NULL COMMENT '字典名称',
    status TINYINT DEFAULT 1 COMMENT '状态',
    remark VARCHAR(500) COMMENT '备注',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_dict_type (dict_type)
) COMMENT '字典类型表';

-- 字典数据表
CREATE TABLE sys_dict_data (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    dict_type VARCHAR(100) NOT NULL COMMENT '字典类型',
    dict_label VARCHAR(100) NOT NULL COMMENT '字典标签',
    dict_value VARCHAR(100) NOT NULL COMMENT '字典值',
    dict_sort INT DEFAULT 0 COMMENT '排序',
    css_class VARCHAR(100) COMMENT 'CSS类名',
    list_class VARCHAR(100) COMMENT '列表样式',
    is_default CHAR(1) DEFAULT 'N' COMMENT '是否默认',
    status TINYINT DEFAULT 1 COMMENT '状态',
    remark VARCHAR(500) COMMENT '备注',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_dict_type (dict_type)
) COMMENT '字典数据表';
```

### 9.2 字典服务

```java
@Service
public class DictService {

    @Autowired
    private DictTypeMapper dictTypeMapper;

    @Autowired
    private DictDataMapper dictDataMapper;

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    private static final String DICT_CACHE_KEY = "sys:dict:";

    /**
     * 获取字典数据 (带缓存)
     */
    public List<DictDataVO> getDictData(String dictType) {
        String cacheKey = DICT_CACHE_KEY + dictType;

        // 先从缓存获取
        List<DictDataVO> cached = (List<DictDataVO>) redisTemplate.opsForValue().get(cacheKey);
        if (cached != null) {
            return cached;
        }

        // 从数据库查询
        List<DictDataVO> data = dictDataMapper.selectByDictType(dictType);

        // 放入缓存
        redisTemplate.opsForValue().set(cacheKey, data, 1, TimeUnit.HOURS);

        return data;
    }

    /**
     * 获取所有字典 (前端初始化用)
     */
    public Map<String, List<DictDataVO>> getAllDict() {
        List<DictType> types = dictTypeMapper.selectAll();
        Map<String, List<DictDataVO>> result = new HashMap<>();

        for (DictType type : types) {
            result.put(type.getDictType(), getDictData(type.getDictType()));
        }

        return result;
    }

    /**
     * 刷新字典缓存
     */
    public void refreshCache(String dictType) {
        String cacheKey = DICT_CACHE_KEY + dictType;
        redisTemplate.delete(cacheKey);
        getDictData(dictType); // 重新加载
    }
}
```

## 十、服务间调用

### 10.1 OpenFeign 配置

```java
// Feign 配置
@Configuration
public class FeignConfig {

    /**
     * 请求拦截器 - 传递租户和用户信息
     */
    @Bean
    public RequestInterceptor requestInterceptor() {
        return template -> {
            // 传递租户ID
            Long tenantId = TenantContext.getTenantId();
            if (tenantId != null) {
                template.header("X-Tenant-Id", tenantId.toString());
            }

            // 传递用户ID
            Long userId = UserContext.getUserId();
            if (userId != null) {
                template.header("X-User-Id", userId.toString());
            }

            // 传递 TraceId
            String traceId = MDC.get("traceId");
            if (traceId != null) {
                template.header("X-Trace-Id", traceId);
            }
        };
    }

    /**
     * 错误解码器
     */
    @Bean
    public ErrorDecoder errorDecoder() {
        return (methodKey, response) -> {
            if (response.status() >= 400) {
                try {
                    String body = Util.toString(response.body().asReader(StandardCharsets.UTF_8));
                    R<?> result = JsonUtils.parse(body, R.class);
                    return new BizException(result.getCode(), result.getMessage());
                } catch (Exception e) {
                    return new BizException(ResultCode.INTERNAL_ERROR);
                }
            }
            return new Default().decode(methodKey, response);
        };
    }
}

// 用户服务 Feign 客户端
@FeignClient(name = "user-service", fallbackFactory = UserClientFallback.class)
public interface UserClient {

    @GetMapping("/api/users/{id}")
    R<UserVO> getById(@PathVariable("id") Long id);

    @GetMapping("/api/users/batch")
    R<List<UserVO>> getByIds(@RequestParam("ids") List<Long> ids);

    @GetMapping("/api/users/current")
    R<UserVO> getCurrentUser();
}

// 降级处理
@Component
public class UserClientFallback implements FallbackFactory<UserClient> {

    @Override
    public UserClient create(Throwable cause) {
        return new UserClient() {
            @Override
            public R<UserVO> getById(Long id) {
                log.error("获取用户信息失败: id={}", id, cause);
                return R.fail("用户服务不可用");
            }

            @Override
            public R<List<UserVO>> getByIds(List<Long> ids) {
                log.error("批量获取用户信息失败", cause);
                return R.fail("用户服务不可用");
            }

            @Override
            public R<UserVO> getCurrentUser() {
                log.error("获取当前用户失败", cause);
                return R.fail("用户服务不可用");
            }
        };
    }
}
```
