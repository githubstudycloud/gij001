# Config Server 配置结构说明

## GitLab 配置仓库目录结构

```
springconfig/
└── config/
    ├── envbeta/                          # Beta 环境
    │   ├── GlobalConfig-pub.properties   # 全局公共配置
    │   ├── project1-v1-pub.properties    # project1 项目配置
    │   └── project2-v1-pub.properties    # project2 项目配置
    ├── envpro/                           # 生产环境
    │   ├── GlobalConfig-pub.properties   # 全局公共配置
    │   ├── project1-v1-pub.properties    # project1 项目配置
    │   └── project2-v1-pub.properties    # project2 项目配置
    └── envtest/                          # 测试环境
        ├── GlobalConfig-pub.properties   # 全局公共配置
        ├── project1-v1-pub.properties    # project1 项目配置
        └── project2-v1-pub.properties    # project2 项目配置
```

## 配置文件命名规范

- **全局配置**: `GlobalConfig-pub.properties`
- **项目配置**: `{application}-v1-pub.properties`

## 客户端获取配置方式

### URL 格式
```
GET /{application}/{profile}/{label}
```

### 参数说明
- `application`: 应用名称 (如 project1, GlobalConfig)
- `profile`: 环境 (beta, pro, test)
- `label`: Git 分支 (默认 main)

### 示例请求
```bash
# 获取 project1 在 test 环境的配置
curl http://localhost:8888/project1-v1-pub/test/main

# 获取全局配置
curl http://localhost:8888/GlobalConfig-pub/test/main

# 搜索路径会自动查找: config/envtest/project1-v1-pub.properties
```

## Config Server 配置说明

### application.yml 关键配置
```yaml
spring:
  cloud:
    config:
      server:
        git:
          uri: ${GITLAB_REPO_URL}
          basedir: ${CONFIG_BASEDIR:${user.home}/config-repo}  # 本地缓存目录
          force-pull: true                                      # 强制拉取最新
          search-paths:
            - 'config/env{profile}'                             # 搜索路径模板
```

### search-paths 占位符
- `{application}`: 替换为应用名称
- `{profile}`: 替换为环境名称 (beta/pro/test)
- `{label}`: 替换为分支名

## 客户端 Spring Boot 配置

### bootstrap.yml
```yaml
spring:
  application:
    name: project1-v1-pub          # 对应配置文件名
  cloud:
    config:
      uri: http://config-server:8888
      profile: ${SPRING_PROFILES_ACTIVE:test}
      label: main
      name: project1-v1-pub,GlobalConfig-pub  # 多个配置文件用逗号分隔
```

### 环境变量
```bash
# 指定环境
export SPRING_PROFILES_ACTIVE=beta

# 指定配置中心地址
export SPRING_CLOUD_CONFIG_URI=http://config-server:8888
```
