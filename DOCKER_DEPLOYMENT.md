# Docker 部署指南

## 概述

本项目提供了完整的 Docker 部署方案，无需在本地或服务器上安装 Maven 或 JDK。

## 架构说明

### Multi-Stage构建

使用 Docker 多阶段构建实现以下优势：

1. **构建阶段**：使用 `maven:3.9.9-eclipse-temurin-21` 镜像构建项目
2. **运行阶段**：使用轻量级 `eclipse-temurin:21-jre-alpine` 镜像运行应用
3. **镜像优化**：最终镜像只包含运行所需的 JRE 和 JAR 文件

### 服务组成

- **platform-config**：配置服务器 (端口 8888)
- **platform-test**：测试应用 (端口 8080)

## 前置条件

### 必需软件

- Docker Engine 20.10+
- Docker Compose v2.0+

### 验证安装

```bash
# 检查 Docker
docker --version

# 检查 Docker Compose
docker compose version
```

## 部署步骤

### 方案一：本地 Windows 部署

#### 1. 克隆项目

```bash
git clone git@github.com:githubstudycloud/gij001.git
cd gij001
```

#### 2. 设置环境变量 (可选)

创建 `.env` 文件:

```env
GITLAB_TOKEN=your-gitlab-token
GITLAB_REPO_URL=http://192.168.0.99:8929/xz01/springconfig.git
```

或直接在命令中设置:

```powershell
# PowerShell
$env:GITLAB_TOKEN="your-token"
$env:GITLAB_REPO_URL="http://192.168.0.99:8929/xz01/springconfig.git"
```

#### 3. 构建并启动服务

```bash
# 构建并启动（后台运行）
docker compose up -d --build

# 查看构建进度
docker compose logs -f

# 仅查看特定服务日志
docker compose logs -f platform-config
docker compose logs -f platform-test
```

#### 4. 验证服务

```bash
# 检查容器状态
docker compose ps

# 验证 Config Server
curl http://localhost:8888/actuator/health

# 验证 Test Application
curl http://localhost:8080/api/test/health
curl http://localhost:8080/api/test/config
curl http://localhost:8080/api/test/welcome
```

### 方案二：Ubuntu 服务器部署

#### 1. 连接到服务器

```bash
ssh ubuntu@192.168.197.128
```

#### 2. 克隆项目

```bash
cd ~
git clone https://github.com/githubstudycloud/gij001.git platform
cd platform
```

#### 3. 设置环境变量

```bash
export GITLAB_TOKEN=your-gitlab-token-here
export GITLAB_REPO_URL=http://192.168.0.99:8929/xz01/springconfig.git
```

#### 4. 构建并启动

```bash
# 后台构建并启动
docker compose up -d --build

# 查看实时日志
docker compose logs -f
```

#### 5. 验证部署

```bash
# 检查容器状态
docker ps

# 测试服务
curl http://localhost:8888/actuator/health
curl http://localhost:8080/api/test/health
```

## 构建说明

### 首次构建时间

首次构建可能需要 **5-15 分钟**，主要时间消耗在：

1. 下载基础镜像 (maven:3.9.9-eclipse-temurin-21)
2. 下载 Maven 依赖包
3. 编译 Java 代码
4. 创建最终运行镜像

### 后续构建

由于 Docker 层缓存机制，后续构建会显著加快：
- 如果代码未变化：**< 1 分钟**
- 如果依赖未变化：**2-3 分钟**

## 常用命令

### 服务管理

```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 重启服务
docker compose restart

# 查看服务状态
docker compose ps

# 查看服务日志
docker compose logs -f

# 只查看最近100行日志
docker compose logs --tail=100 -f
```

### 容器管理

```bash
# 进入容器
docker exec -it platform-config sh
docker exec -it platform-test sh

# 查看容器资源使用
docker stats

# 查看容器详细信息
docker inspect platform-config
```

### 镜像管理

```bash
# 查看镜像列表
docker images

# 删除未使用的镜像
docker image prune -a

# 重新构建镜像
docker compose build --no-cache
```

## 健康检查

### 自动健康检查

Docker Compose 配置了自动健康检查：

- **Config Server**: 每 10 秒检查一次 `/actuator/health`
- **Test Application**: 等待 Config Server 健康后启动

### 手动健康检查

```bash
# Config Server
docker exec platform-config wget -qO- http://localhost:8888/actuator/health

# Test Application
docker exec platform-test wget -qO- http://localhost:8080/api/test/health
```

## 网络配置

### 容器网络

服务使用自定义 bridge 网络 `platform-network`：

- 容器间可通过服务名通信
- Test Application 通过 `http://platform-config:8888` 访问配置服务器

### 端口映射

| 服务 | 容器端口 | 主机端口 | 说明 |
|------|----------|----------|------|
| platform-config | 8888 | 8888 | Config Server |
| platform-test | 8080 | 8080 | Test Application |

## 环境变量

### Config Server

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| GITLAB_TOKEN | (required) | GitLab 访问令牌 |
| GITLAB_REPO_URL | http://192.168.0.99:8929/xz01/springconfig.git | GitLab 仓库 URL |

### Test Application

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| SPRING_CLOUD_CONFIG_URI | http://platform-config:8888 | Config Server 地址 |

## 故障排查

### 问题 1：构建超时

**症状**：
```
ERROR: build timeout
```

**解决方案**：
1. 检查网络连接
2. 增加 Docker 构建超时时间
3. 使用国内 Maven 镜像源（修改 Dockerfile 添加 settings.xml）

### 问题 2：Config Server 无法连接 GitLab

**症状**：
```
Cannot clone or checkout repository
```

**解决方案**：
1. 验证 GITLAB_TOKEN 是否正确
2. 检查 GITLAB_REPO_URL 是否可访问
3. 查看容器日志：`docker compose logs platform-config`

### 问题 3：Test Application 无法连接 Config Server

**症状**：
```
Could not locate PropertySource
```

**解决方案**：
1. 确认 Config Server 已启动：`docker ps`
2. 检查健康状态：`curl http://localhost:8888/actuator/health`
3. 验证网络连接：`docker network inspect platform_platform-network`

### 问题 4：端口被占用

**症状**：
```
Bind for 0.0.0.0:8888 failed: port is already allocated
```

**解决方案**：
```bash
# Windows
netstat -ano | findstr :8888
taskkill /PID <PID> /F

# Linux
lsof -i :8888
kill -9 <PID>

# 或修改 docker-compose.yml 中的端口映射
```

### 问题 5：容器内存不足

**症状**：
```
Java heap space
```

**解决方案**：

修改 Dockerfile，添加 JVM 参数：

```dockerfile
ENTRYPOINT ["java", \
    "-Xms512m", \
    "-Xmx1024m", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-jar", \
    "app.jar"]
```

## 性能优化

### 1. 使用 Maven 缓存

创建 `~/.m2` 卷挂载以加速构建：

```yaml
services:
  platform-config:
    build:
      context: .
      dockerfile: Dockerfile.config
    volumes:
      - ~/.m2:/root/.m2
```

### 2. 多阶段构建优化

已实现：
- ✅ 分离构建和运行阶段
- ✅ 使用 alpine 轻量级镜像
- ✅ 仅复制必要的 JAR 文件

### 3. 镜像层缓存

Dockerfile 已优化：
- 先复制 POM 文件
- 再复制源代码
- 最大化利用 Docker 层缓存

## 生产环境建议

### 1. 使用外部配置

不要将敏感信息硬编码到镜像中：

```bash
# 使用 secrets
docker secret create gitlab_token token.txt
```

### 2. 资源限制

在 docker-compose.yml 中添加资源限制：

```yaml
services:
  platform-config:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          memory: 512M
```

### 3. 日志管理

配置日志驱动：

```yaml
services:
  platform-config:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### 4. 自动重启

```yaml
services:
  platform-config:
    restart: unless-stopped
```

## API 测试

### Config Server

```bash
# 健康检查
curl http://localhost:8888/actuator/health

# 配置信息
curl http://localhost:8888/actuator/info

# 获取应用配置
curl http://localhost:8888/test-application/default
```

### Test Application

```bash
# 健康检查
curl http://localhost:8080/api/test/health

# 配置测试
curl http://localhost:8080/api/test/config

# 欢迎信息
curl http://localhost:8080/api/test/welcome
```

## 监控

### 查看实时日志

```bash
# 所有服务
docker compose logs -f

# 特定服务
docker compose logs -f platform-config

# 最近 100 行
docker compose logs --tail=100 platform-test
```

### 查看资源使用

```bash
# 实时监控
docker stats

# 一次性查看
docker stats --no-stream
```

## 清理

### 停止并删除服务

```bash
# 停止服务
docker compose down

# 停止并删除卷
docker compose down -v

# 停止并删除镜像
docker compose down --rmi all
```

### 清理系统

```bash
# 删除未使用的容器、网络、镜像
docker system prune -a

# 删除所有（包括卷）
docker system prune -a --volumes
```

## 总结

### 优势

✅ 无需安装 Maven 或 JDK
✅ 环境一致性
✅ 快速部署
✅ 易于扩展
✅ 资源隔离

### 适用场景

- 开发环境快速搭建
- CI/CD 自动化部署
- 生产环境容器化部署
- 微服务架构部署

---

**文档创建**: 2025-12-02
**适用版本**: Docker 20.10+, Docker Compose v2.0+
**项目版本**: Spring Boot 4.0.0, JDK 21
