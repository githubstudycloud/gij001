#!/bin/bash
# Docker 一键部署脚本
# 用于快速部署 Platform 项目到 Docker

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
GITLAB_TOKEN="${GITLAB_TOKEN:-your-gitlab-token-here}"
GITLAB_REPO_URL="${GITLAB_REPO_URL:-http://192.168.0.99:8929/xz01/springconfig.git}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Platform Docker 部署${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装${NC}"
    echo "请安装 Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# 检查 Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${RED}错误: Docker Compose 未安装或版本过低${NC}"
    echo "需要 Docker Compose v2.0+"
    exit 1
fi

echo -e "${CYAN}Docker 版本:${NC} $(docker --version)"
echo -e "${CYAN}Docker Compose 版本:${NC} $(docker compose version --short)"
echo ""

# 设置环境变量
export GITLAB_TOKEN
export GITLAB_REPO_URL

echo -e "${YELLOW}配置信息:${NC}"
echo -e "  GitLab URL: ${CYAN}$GITLAB_REPO_URL${NC}"
echo -e "  Token: ${CYAN}${GITLAB_TOKEN:0:15}...${NC}"
echo ""

# 解析参数
ACTION="${1:-up}"

case $ACTION in
    up|start)
        echo -e "${YELLOW}[1/3] 构建 Docker 镜像...${NC}"
        echo -e "${CYAN}提示: 首次构建可能需要 5-15 分钟${NC}"
        docker compose build

        echo ""
        echo -e "${YELLOW}[2/3] 启动服务...${NC}"
        docker compose up -d

        echo ""
        echo -e "${YELLOW}[3/3] 等待服务就绪...${NC}"
        sleep 10

        # 检查服务状态
        echo ""
        echo -e "${YELLOW}服务状态:${NC}"
        docker compose ps

        # 等待健康检查
        echo ""
        echo -e "${YELLOW}等待健康检查 (最多60秒)...${NC}"
        for i in {1..12}; do
            if docker compose ps | grep -q "healthy"; then
                echo -e "${GREEN}✓ 服务健康检查通过${NC}"
                break
            fi
            echo -n "."
            sleep 5
        done
        echo ""

        # 验证服务
        echo ""
        echo -e "${YELLOW}验证服务...${NC}"

        # Config Server
        if curl -sf http://localhost:8888/actuator/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Config Server 运行正常${NC} - http://localhost:8888"
        else
            echo -e "${YELLOW}⚠ Config Server 可能仍在启动中${NC}"
        fi

        # Test Application
        if curl -sf http://localhost:8080/api/test/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Test Application 运行正常${NC} - http://localhost:8080"
        else
            echo -e "${YELLOW}⚠ Test Application 可能仍在启动中${NC}"
        fi

        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}部署完成！${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo -e "${CYAN}访问地址:${NC}"
        echo -e "  Config Server:     ${YELLOW}http://localhost:8888/actuator/health${NC}"
        echo -e "  Test Application:  ${YELLOW}http://localhost:8080/api/test/health${NC}"
        echo -e "  配置测试:          ${YELLOW}http://localhost:8080/api/test/config${NC}"
        echo -e "  欢迎信息:          ${YELLOW}http://localhost:8080/api/test/welcome${NC}"
        echo ""
        echo -e "${CYAN}常用命令:${NC}"
        echo -e "  查看日志:   ${YELLOW}docker compose logs -f${NC}"
        echo -e "  停止服务:   ${YELLOW}$0 down${NC}"
        echo -e "  重启服务:   ${YELLOW}$0 restart${NC}"
        echo -e "  查看状态:   ${YELLOW}$0 status${NC}"
        ;;

    down|stop)
        echo -e "${YELLOW}停止服务...${NC}"
        docker compose down
        echo -e "${GREEN}✓ 服务已停止${NC}"
        ;;

    restart)
        echo -e "${YELLOW}重启服务...${NC}"
        docker compose restart
        echo -e "${GREEN}✓ 服务已重启${NC}"
        ;;

    status)
        echo -e "${YELLOW}服务状态:${NC}"
        docker compose ps
        echo ""
        echo -e "${YELLOW}资源使用:${NC}"
        docker stats --no-stream platform-config platform-test 2>/dev/null || \
            echo -e "${RED}服务未运行${NC}"
        ;;

    logs)
        docker compose logs -f
        ;;

    build)
        echo -e "${YELLOW}重新构建镜像...${NC}"
        docker compose build --no-cache
        echo -e "${GREEN}✓ 构建完成${NC}"
        ;;

    clean)
        echo -e "${YELLOW}清理所有资源...${NC}"
        docker compose down -v --rmi all
        echo -e "${GREEN}✓ 清理完成${NC}"
        ;;

    test)
        echo -e "${YELLOW}测试 API 端点...${NC}"
        echo ""

        echo -e "${CYAN}1. Config Server 健康检查:${NC}"
        curl -s http://localhost:8888/actuator/health | jq . || \
            echo -e "${RED}✗ 失败${NC}"
        echo ""

        echo -e "${CYAN}2. Test Application 健康检查:${NC}"
        curl -s http://localhost:8080/api/test/health | jq . || \
            echo -e "${RED}✗ 失败${NC}"
        echo ""

        echo -e "${CYAN}3. 配置测试:${NC}"
        curl -s http://localhost:8080/api/test/config | jq . || \
            echo -e "${RED}✗ 失败${NC}"
        echo ""

        echo -e "${CYAN}4. 欢迎信息:${NC}"
        curl -s http://localhost:8080/api/test/welcome | jq . || \
            echo -e "${RED}✗ 失败${NC}"
        ;;

    help|--help|-h)
        echo "用法: $0 [命令]"
        echo ""
        echo "命令:"
        echo "  up, start    构建并启动服务 (默认)"
        echo "  down, stop   停止服务"
        echo "  restart      重启服务"
        echo "  status       查看服务状态"
        echo "  logs         查看实时日志"
        echo "  build        重新构建镜像"
        echo "  clean        清理所有资源"
        echo "  test         测试 API 端点"
        echo "  help         显示帮助信息"
        echo ""
        echo "环境变量:"
        echo "  GITLAB_TOKEN      GitLab 访问令牌"
        echo "  GITLAB_REPO_URL   GitLab 仓库 URL"
        echo ""
        echo "示例:"
        echo "  $0              # 启动服务"
        echo "  $0 logs         # 查看日志"
        echo "  $0 test         # 测试 API"
        echo "  $0 down         # 停止服务"
        ;;

    *)
        echo -e "${RED}错误: 未知命令 '$ACTION'${NC}"
        echo "使用 '$0 help' 查看帮助信息"
        exit 1
        ;;
esac

echo ""
