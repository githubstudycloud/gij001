# Spring Cloud Config Server 配置指南

## 概述

Platform Config Server 是基于 Spring Cloud Config 的配置中心，支持从 GitLab 或本地文件系统获取配置。

## 目录结构

### GitLab 仓库结构 (xz01/springconfig)

```
config/
├── envtest/                    # 测试环境
│   ├── GlobalConfig.properties # 全局公共配置
│   └── project1-v1.properties  # 项目专属配置
├── envbeta/                    # Beta 环境
│   ├── GlobalConfig.properties
│   └── project1-v1.properties
└── envpro/                     # 生产环境
    ├── GlobalConfig.properties
    └── project1-v1.properties
```

### 配置文件命名规则

- `GlobalConfig.properties` - 全局公共配置，所有项目共享
- `{project}-v1.properties` - 项目专属配置，如 `project1-v1.properties`
- 环境通过目录区分：`envtest`、`envbeta`、`envpro`

## 运行模式

### 1. Native 模式（本地开发）

从本地文件系统读取配置，无需 GitLab 连接。

```bash
cd platform-config

# Windows CMD
set CONFIG_PROFILE=native
mvn spring-boot:run -DskipTests

# PowerShell
$env:CONFIG_PROFILE="native"
mvn spring-boot:run -DskipTests

# Linux/Mac
CONFIG_PROFILE=native mvn spring-boot:run -DskipTests
```

本地配置文件位置：`docs/sample-config/config/env{profile}/`

### 2. Git 模式（生产环境）

从 GitLab 仓库读取配置。

```bash
cd platform-config

# Windows CMD
set CONFIG_PROFILE=git
set GITLAB_TOKEN=your_gitlab_token
mvn spring-boot:run -DskipTests

# PowerShell
$env:CONFIG_PROFILE="git"
$env:GITLAB_TOKEN="your_gitlab_token"
mvn spring-boot:run -DskipTests

# Linux/Mac
CONFIG_PROFILE=git GITLAB_TOKEN=your_gitlab_token mvn spring-boot:run -DskipTests
```

## 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| CONFIG_PROFILE | native | 运行模式：native 或 git |
| GITLAB_TOKEN | - | GitLab 访问令牌（git 模式必需） |
| GITLAB_REPO_URL | http://192.168.0.99:8929/xz01/springconfig.git | GitLab 仓库地址 |
| CONFIG_BRANCH | main | Git 分支 |
| CONFIG_BASEDIR | ${user.home}/config-repo | Git 克隆目录 |
| CONFIG_FORCE_PULL | true | 是否每次强制拉取最新配置 |
| CONFIG_NATIVE_PATH | ./docs/sample-config | Native 模式配置文件路径 |

## API 接口

### 获取配置

```bash
# 格式: /{application}/{profile}/{label}
# application: 配置文件名（不含 .properties）
# profile: 环境（test/beta/pro）
# label: Git 分支（默认 main）

# 获取 project1-v1 的测试环境配置
curl http://localhost:8888/project1-v1/test/main

# 获取全局配置
curl http://localhost:8888/GlobalConfig/pro/main

# 获取多个配置（项目配置 + 全局配置）
curl http://localhost:8888/project1-v1,GlobalConfig/test/main
```

### 健康检查

```bash
curl http://localhost:8888/actuator/health
```

### API 文档

- Swagger UI: http://localhost:8888/swagger-ui.html
- OpenAPI: http://localhost:8888/v3/api-docs

## 客户端配置

客户端项目需要在 `src/main/resources/bootstrap.yml` 中配置：

```yaml
spring:
  application:
    name: project1-v1  # 对应配置文件名

  cloud:
    config:
      uri: http://localhost:8888
      profile: ${SPRING_PROFILES_ACTIVE:test}
      label: main
      name: ${spring.application.name},GlobalConfig  # 项目配置 + 全局配置
      fail-fast: true
      retry:
        enabled: true
        max-attempts: 6
```

详细模板见：`docs/client-bootstrap-template.yml`

## GitLab 配置文件管理

### 使用 Python 脚本创建配置

```bash
cd platform-config/scripts

# 使用 .env 文件中的 token
python create_gitlab_configs.py

# 指定 token
python create_gitlab_configs.py your_gitlab_token

# 覆盖已存在的文件
python create_gitlab_configs.py --overwrite
```

### 使用 Shell 脚本创建配置

```bash
cd platform-config/scripts

# 使用 .env 文件中的 token
./create_gitlab_configs.sh

# 覆盖已存在的文件
./create_gitlab_configs.sh --overwrite
```

### 获取 GitLab Token

1. 访问 GitLab -> User Settings -> Access Tokens
2. 创建新 Token，勾选 `api` 权限
3. 将 Token 保存到项目根目录 `.env` 文件：
   ```
   GITLAB_TOKEN=glpat-xxxxxxxx
   GITLAB_URL=http://192.168.0.99:8929
   ```

## 配置优先级

当客户端配置 `name: project1-v1,GlobalConfig` 时，配置加载顺序：

1. `project1-v1.properties` - 项目专属配置（最高优先级）
2. `GlobalConfig.properties` - 全局公共配置

同名配置项，项目配置会覆盖全局配置。

## IDEA 运行配置

在 IntelliJ IDEA 中配置 ConfigServerApplication：

1. 打开 Run/Debug Configurations
2. 选择 ConfigServerApplication
3. 添加环境变量：
   - `CONFIG_PROFILE=git`（或 `native`）
   - `GITLAB_TOKEN=your_token`（git 模式需要）

## 常见问题

### Q: 启动报错 "Cannot clone or checkout repository"

A: 检查 GITLAB_TOKEN 是否正确设置，确保 token 有 `api` 权限。

### Q: 获取配置返回 404

A: 检查：
1. 配置文件是否存在于 GitLab/本地目录
2. 请求路径是否正确（application/profile/label）
3. 目录结构是否为 `config/env{profile}/{application}.properties`

### Q: 端口 8888 被占用

A: 终止占用端口的进程或修改 `server.port` 配置。

## 版本信息

- Spring Boot: 4.0.0
- Spring Cloud: 2025.1.0
- Java: 25+
