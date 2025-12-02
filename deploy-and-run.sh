#!/bin/bash

# Platform项目部署和运行脚本
# 用于在Ubuntu服务器上部署和运行Spring Boot应用

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
PROJECT_NAME="platform"
REMOTE_SERVER="ubuntu@192.168.197.128"
REMOTE_DIR="/opt/platform"
GITLAB_TOKEN="${GITLAB_TOKEN:-your-gitlab-token-here}"
GITLAB_REPO_URL="${GITLAB_REPO_URL:-http://192.168.0.99:8929/xz01/springconfig.git}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Platform项目部署脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查参数
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --local          在本地运行（需要Maven）"
    echo "  --remote         在远程服务器运行（默认）"
    echo "  --docker         使用Docker运行"
    echo "  --build-only     仅构建，不运行"
    echo "  --help, -h       显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  GITLAB_TOKEN     GitLab访问令牌"
    echo "  GITLAB_REPO_URL  GitLab仓库URL"
    exit 0
fi

MODE="${1:-remote}"

# 函数：检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}错误: $1 未安装${NC}"
        return 1
    fi
    return 0
}

# 函数：本地构建
build_local() {
    echo -e "${YELLOW}[1/3] 检查Maven...${NC}"
    if ! check_command mvn; then
        echo -e "${RED}本地未安装Maven，请使用 --remote 或 --docker 模式${NC}"
        exit 1
    fi

    echo -e "${YELLOW}[2/3] 构建项目...${NC}"
    mvn clean package -DskipTests

    echo -e "${GREEN}✓ 构建完成${NC}"
    echo ""
    echo "生成的JAR文件:"
    ls -lh platform-config/target/*.jar 2>/dev/null || true
    ls -lh platform-test/target/*.jar 2>/dev/null || true
}

# 函数：本地运行
run_local() {
    echo -e "${YELLOW}[3/3] 启动应用...${NC}"

    # 设置环境变量
    export GITLAB_TOKEN
    export GITLAB_REPO_URL

    echo -e "${YELLOW}启动Config Server...${NC}"
    cd platform-config
    mvn spring-boot:run &
    CONFIG_PID=$!
    cd ..

    echo -e "${YELLOW}等待Config Server启动...${NC}"
    sleep 30

    echo -e "${YELLOW}启动Test Application...${NC}"
    cd platform-test
    mvn spring-boot:run &
    TEST_PID=$!
    cd ..

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}应用已启动${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Config Server: ${YELLOW}http://localhost:8888${NC} (PID: $CONFIG_PID)"
    echo -e "Test App:      ${YELLOW}http://localhost:8080${NC} (PID: $TEST_PID)"
    echo ""
    echo "按 Ctrl+C 停止所有服务"

    # 等待进程
    wait
}

# 函数：远程部署
deploy_remote() {
    echo -e "${YELLOW}[1/6] 检查SSH连接...${NC}"
    if ! ssh -o ConnectTimeout=5 $REMOTE_SERVER "echo '连接成功'" &>/dev/null; then
        echo -e "${RED}无法连接到远程服务器: $REMOTE_SERVER${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ SSH连接正常${NC}"

    echo -e "${YELLOW}[2/6] 创建远程目录...${NC}"
    ssh $REMOTE_SERVER "mkdir -p $REMOTE_DIR"

    echo -e "${YELLOW}[3/6] 上传项目文件...${NC}"
    rsync -avz --exclude 'target' --exclude '.git' --exclude '.idea' \
        ./ $REMOTE_SERVER:$REMOTE_DIR/

    echo -e "${YELLOW}[4/6] 远程构建...${NC}"
    ssh $REMOTE_SERVER << EOF
        cd $REMOTE_DIR
        export GITLAB_TOKEN=$GITLAB_TOKEN
        export GITLAB_REPO_URL=$GITLAB_REPO_URL
        mvn clean package -DskipTests
EOF

    echo -e "${YELLOW}[5/6] 停止旧服务...${NC}"
    ssh $REMOTE_SERVER << EOF
        pkill -f "platform-config" || true
        pkill -f "platform-test" || true
        sleep 3
EOF

    echo -e "${YELLOW}[6/6] 启动服务...${NC}"
    ssh $REMOTE_SERVER << EOF
        cd $REMOTE_DIR
        export GITLAB_TOKEN=$GITLAB_TOKEN
        export GITLAB_REPO_URL=$GITLAB_REPO_URL

        # 启动Config Server
        nohup java -jar platform-config/target/platform-config-1.0.0-SNAPSHOT.jar \
            > logs/config-server.log 2>&1 &
        echo \$! > config-server.pid

        # 等待Config Server启动
        sleep 30

        # 启动Test Application
        nohup java -jar platform-test/target/platform-test-1.0.0-SNAPSHOT.jar \
            > logs/test-app.log 2>&1 &
        echo \$! > test-app.pid

        echo "服务已启动"
        echo "Config Server PID: \$(cat config-server.pid)"
        echo "Test App PID: \$(cat test-app.pid)"
EOF

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}远程部署完成${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Config Server: ${YELLOW}http://192.168.197.128:8888${NC}"
    echo -e "Test App:      ${YELLOW}http://192.168.197.128:8080${NC}"
    echo ""
    echo "查看日志:"
    echo "  ssh $REMOTE_SERVER 'tail -f $REMOTE_DIR/logs/config-server.log'"
    echo "  ssh $REMOTE_SERVER 'tail -f $REMOTE_DIR/logs/test-app.log'"
}

# 函数：Docker部署
deploy_docker() {
    echo -e "${YELLOW}[1/4] 构建项目...${NC}"
    build_local

    echo -e "${YELLOW}[2/4] 创建Docker镜像...${NC}"

    # 创建Dockerfile for config-server
    cat > platform-config/Dockerfile << 'DOCKERFILE'
FROM eclipse-temurin:25-jdk-alpine
WORKDIR /app
COPY target/platform-config-1.0.0-SNAPSHOT.jar app.jar
EXPOSE 8888
ENTRYPOINT ["java", "-jar", "app.jar"]
DOCKERFILE

    # 创建Dockerfile for test-app
    cat > platform-test/Dockerfile << 'DOCKERFILE'
FROM eclipse-temurin:25-jdk-alpine
WORKDIR /app
COPY target/platform-test-1.0.0-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
DOCKERFILE

    echo -e "${YELLOW}[3/4] 构建Docker镜像...${NC}"
    docker build -t platform-config:latest platform-config/
    docker build -t platform-test:latest platform-test/

    echo -e "${YELLOW}[4/4] 启动容器...${NC}"

    # 停止旧容器
    docker stop platform-config platform-test 2>/dev/null || true
    docker rm platform-config platform-test 2>/dev/null || true

    # 创建网络
    docker network create platform-network 2>/dev/null || true

    # 启动Config Server
    docker run -d \
        --name platform-config \
        --network platform-network \
        -p 8888:8888 \
        -e GITLAB_TOKEN=$GITLAB_TOKEN \
        -e GITLAB_REPO_URL=$GITLAB_REPO_URL \
        platform-config:latest

    echo -e "${YELLOW}等待Config Server启动...${NC}"
    sleep 30

    # 启动Test Application
    docker run -d \
        --name platform-test \
        --network platform-network \
        -p 8080:8080 \
        -e SPRING_CLOUD_CONFIG_URI=http://platform-config:8888 \
        platform-test:latest

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Docker部署完成${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Config Server: ${YELLOW}http://localhost:8888${NC}"
    echo -e "Test App:      ${YELLOW}http://localhost:8080${NC}"
    echo ""
    echo "查看日志:"
    echo "  docker logs -f platform-config"
    echo "  docker logs -f platform-test"
}

# 主流程
case $MODE in
    --local)
        build_local
        run_local
        ;;
    --remote)
        deploy_remote
        ;;
    --docker)
        if ! check_command docker; then
            echo -e "${RED}Docker未安装${NC}"
            exit 1
        fi
        deploy_docker
        ;;
    --build-only)
        build_local
        ;;
    *)
        echo -e "${RED}未知选项: $MODE${NC}"
        echo "使用 --help 查看帮助"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}完成！${NC}"
