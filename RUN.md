# 项目打包和运行指南

## 方案一：使用IntelliJ IDEA运行（推荐）

### 前置条件
- IntelliJ IDEA已安装
- JDK 17或更高版本（推荐JDK 25）
- 项目已导入IDEA

### 运行步骤

#### 1. 启动Config Server（配置中心）

**方式A：通过IDEA运行**
1. 在IDEA中打开项目
2. 找到 `platform-config/src/main/java/com/platform/config/ConfigServerApplication.java`
3. 右键点击 → Run 'ConfigServerApplication'
4. 等待启动，观察控制台输出
5. 验证：访问 http://localhost:8888/actuator/health

**方式B：通过Maven运行**
1. 在IDEA底部打开Terminal
2. 执行命令：
```bash
cd platform-config
mvn spring-boot:run
```

**设置环境变量（可选）**：
```bash
# 在IDEA的Run Configuration中设置环境变量
GITLAB_TOKEN=your-gitlab-token-here
GITLAB_REPO_URL=http://192.168.0.99:8929/xz01/springconfig.git
```

或者在启动前执行：
```bash
# PowerShell
$env:GITLAB_TOKEN="your-token"
```

#### 2. 启动Test Application（测试应用）

**方式A：通过IDEA运行**
1. 找到 `platform-test/src/main/java/com/platform/test/TestApplication.java`
2. 右键点击 → Run 'TestApplication'
3. 等待启动，观察控制台输出
4. 验证：访问 http://localhost:8080/api/test/health

**方式B：通过Maven运行**
```bash
cd platform-test
mvn spring-boot:run
```

#### 3. 测试API

```bash
# 健康检查
curl http://localhost:8080/api/test/health

# 配置测试
curl http://localhost:8080/api/test/config

# 欢迎信息
curl http://localhost:8080/api/test/welcome
```

---

## 方案二：在远程Ubuntu服务器上运行

### 前置条件
- Ubuntu服务器已配置（192.168.197.128）
- Docker已安装
- Git已配置

### 部署步骤

#### 1. 连接到服务器
```bash
ssh ubuntu@192.168.197.128
```

#### 2. 克隆项目
```bash
cd ~
git clone git@github.com:githubstudycloud/gij001.git
cd gij001
```

#### 3. 设置环境变量
```bash
export GITLAB_TOKEN=glpat-your-token
export GITLAB_REPO_URL=http://192.168.0.99:8929/xz01/springconfig.git
```

#### 4. 构建项目
```bash
mvn clean package -DskipTests
```

#### 5. 运行Config Server
```bash
cd platform-config
java -jar target/platform-config-1.0.0-SNAPSHOT.jar &
```

#### 6. 运行Test Application
```bash
cd ../platform-test
java -jar target/platform-test-1.0.0-SNAPSHOT.jar &
```

#### 7. 验证服务
```bash
# 检查Config Server
curl http://localhost:8888/actuator/health

# 检查Test Application
curl http://localhost:8080/api/test/health
```

---

## 方案三：使用Docker运行（推荐生产环境）

### 1. 创建Dockerfile

**platform-config/Dockerfile**:
```dockerfile
FROM eclipse-temurin:25-jdk-alpine
WORKDIR /app
COPY target/platform-config-1.0.0-SNAPSHOT.jar app.jar
EXPOSE 8888
ENV GITLAB_TOKEN=""
ENV GITLAB_REPO_URL=""
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**platform-test/Dockerfile**:
```dockerfile
FROM eclipse-temurin:25-jdk-alpine
WORKDIR /app
COPY target/platform-test-1.0.0-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 2. 创建docker-compose.yml

```yaml
version: '3.8'

services:
  config-server:
    build:
      context: ./platform-config
    container_name: platform-config
    ports:
      - "8888:8888"
    environment:
      - GITLAB_TOKEN=${GITLAB_TOKEN}
      - GITLAB_REPO_URL=${GITLAB_REPO_URL}
    networks:
      - platform-network

  test-app:
    build:
      context: ./platform-test
    container_name: platform-test
    ports:
      - "8080:8080"
    depends_on:
      - config-server
    environment:
      - SPRING_CLOUD_CONFIG_URI=http://config-server:8888
    networks:
      - platform-network

networks:
  platform-network:
    driver: bridge
```

### 3. 构建和运行
```bash
# 先打包
mvn clean package -DskipTests

# 使用Docker Compose启动
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

---

## 方案四：快速启动脚本

### Windows (PowerShell)

创建 `run.ps1`:
```powershell
# 设置环境变量
$env:GITLAB_TOKEN = "your-token"
$env:GITLAB_REPO_URL = "http://192.168.0.99:8929/xz01/springconfig.git"

Write-Host "Starting Config Server..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd platform-config; mvn spring-boot:run"

Start-Sleep -Seconds 30

Write-Host "Starting Test Application..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd platform-test; mvn spring-boot:run"

Write-Host "`nServices are starting..." -ForegroundColor Yellow
Write-Host "Config Server: http://localhost:8888" -ForegroundColor Cyan
Write-Host "Test App: http://localhost:8080" -ForegroundColor Cyan
```

### Linux/Mac (Bash)

创建 `run.sh`:
```bash
#!/bin/bash

# 设置环境变量
export GITLAB_TOKEN="your-token"
export GITLAB_REPO_URL="http://192.168.0.99:8929/xz01/springconfig.git"

echo "Starting Config Server..."
cd platform-config
mvn spring-boot:run &
CONFIG_PID=$!

sleep 30

echo "Starting Test Application..."
cd ../platform-test
mvn spring-boot:run &
TEST_PID=$!

echo ""
echo "Services are running:"
echo "Config Server: http://localhost:8888 (PID: $CONFIG_PID)"
echo "Test App: http://localhost:8080 (PID: $TEST_PID)"
echo ""
echo "Press Ctrl+C to stop all services"

# 等待进程
wait
```

---

## 打包成可执行JAR

### 1. 构建所有模块
```bash
mvn clean package -DskipTests
```

### 2. 查看生成的JAR
```bash
# Config Server JAR
ls -lh platform-config/target/platform-config-1.0.0-SNAPSHOT.jar

# Test Application JAR
ls -lh platform-test/target/platform-test-1.0.0-SNAPSHOT.jar
```

### 3. 单独运行JAR
```bash
# 运行Config Server
java -jar platform-config/target/platform-config-1.0.0-SNAPSHOT.jar

# 运行Test Application
java -jar platform-test/target/platform-test-1.0.0-SNAPSHOT.jar
```

### 4. 带参数运行
```bash
# 指定配置文件
java -jar platform-config/target/platform-config-1.0.0-SNAPSHOT.jar \
  --spring.profiles.active=prod

# 指定端口
java -jar platform-test/target/platform-test-1.0.0-SNAPSHOT.jar \
  --server.port=9090

# 指定环境变量
java -jar -DGITLAB_TOKEN=your-token \
  platform-config/target/platform-config-1.0.0-SNAPSHOT.jar
```

---

## 故障排查

### 问题1：Maven命令找不到

**解决方案**：
1. 检查Maven是否安装：`mvn -version`
2. 如果未安装，下载安装Maven：https://maven.apache.org/download.cgi
3. 配置MAVEN_HOME和PATH环境变量
4. 或使用IDEA内置Maven

### 问题2：端口被占用

**错误信息**：
```
Port 8888 was already in use
```

**解决方案**：
```bash
# Windows
netstat -ano | findstr :8888
taskkill /PID <PID> /F

# Linux/Mac
lsof -i :8888
kill -9 <PID>

# 或修改application.yml中的端口
```

### 问题3：无法连接GitLab

**错误信息**：
```
Cannot clone or checkout repository
```

**解决方案**：
1. 检查GITLAB_TOKEN是否设置
2. 验证GitLab URL是否可访问
3. 检查网络连接和代理设置
4. 临时使用本地配置（不依赖GitLab）

### 问题4：JDK版本不匹配

**错误信息**：
```
unsupported class file version
```

**解决方案**：
1. 检查JDK版本：`java -version`
2. 确保使用JDK 17或更高版本
3. 推荐使用JDK 25
4. 配置IDEA使用正确的JDK

---

## 性能优化

### JVM参数调优
```bash
java -Xms512m -Xmx1024m \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -jar platform-test/target/platform-test-1.0.0-SNAPSHOT.jar
```

### Spring Boot优化
```yaml
# application.yml
spring:
  main:
    lazy-initialization: true
  jmx:
    enabled: false
```

---

## 监控和管理

### Actuator端点

**Config Server**:
```bash
# 健康检查
curl http://localhost:8888/actuator/health

# 配置服务器状态
curl http://localhost:8888/actuator/configserver
```

**Test Application**:
```bash
# 健康检查
curl http://localhost:8080/actuator/health

# 刷新配置
curl -X POST http://localhost:8080/actuator/refresh

# 查看所有端点
curl http://localhost:8080/actuator
```

---

## 推荐运行方式

### 开发环境
✅ **方案一**：使用IntelliJ IDEA运行
- 优点：方便调试、热部署、实时日志
- 适合：日常开发、测试

### 测试环境
✅ **方案二**：在Ubuntu服务器运行JAR
- 优点：接近生产环境、易于测试
- 适合：集成测试、性能测试

### 生产环境
✅ **方案三**：使用Docker运行
- 优点：隔离性好、易于部署、资源控制
- 适合：正式部署、容器化环境

---

**文档创建**: 2025-12-02
**适用版本**: Spring Boot 4.0.0, JDK 17-25
