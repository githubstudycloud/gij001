# Docker 一键部署脚本 (PowerShell)
# 用于快速部署 Platform 项目到 Docker

param(
    [Parameter(Position=0)]
    [string]$Action = "up"
)

# 配置
$GITLAB_TOKEN = if ($env:GITLAB_TOKEN) { $env:GITLAB_TOKEN } else { "your-gitlab-token-here" }
$GITLAB_REPO_URL = if ($env:GITLAB_REPO_URL) { $env:GITLAB_REPO_URL } else { "http://192.168.0.99:8929/xz01/springconfig.git" }

Write-Host "========================================" -ForegroundColor Green
Write-Host "Platform Docker 部署" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 检查 Docker
try {
    $dockerVersion = docker --version
    Write-Host "Docker 版本: $dockerVersion" -ForegroundColor Cyan
} catch {
    Write-Host "错误: Docker 未安装" -ForegroundColor Red
    Write-Host "请安装 Docker Desktop: https://docs.docker.com/desktop/install/windows-install/" -ForegroundColor Yellow
    exit 1
}

# 检查 Docker Compose
try {
    $composeVersion = docker compose version --short
    Write-Host "Docker Compose 版本: $composeVersion" -ForegroundColor Cyan
} catch {
    Write-Host "错误: Docker Compose 未安装或版本过低" -ForegroundColor Red
    Write-Host "需要 Docker Compose v2.0+" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# 设置环境变量
$env:GITLAB_TOKEN = $GITLAB_TOKEN
$env:GITLAB_REPO_URL = $GITLAB_REPO_URL

Write-Host "配置信息:" -ForegroundColor Yellow
Write-Host "  GitLab URL: $GITLAB_REPO_URL" -ForegroundColor Cyan
Write-Host "  Token: $($GITLAB_TOKEN.Substring(0,15))..." -ForegroundColor Cyan
Write-Host ""

switch ($Action.ToLower()) {
    { $_ -in "up", "start" } {
        Write-Host "[1/3] 构建 Docker 镜像..." -ForegroundColor Yellow
        Write-Host "提示: 首次构建可能需要 5-15 分钟" -ForegroundColor Cyan
        docker compose build

        Write-Host ""
        Write-Host "[2/3] 启动服务..." -ForegroundColor Yellow
        docker compose up -d

        Write-Host ""
        Write-Host "[3/3] 等待服务就绪..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10

        # 检查服务状态
        Write-Host ""
        Write-Host "服务状态:" -ForegroundColor Yellow
        docker compose ps

        # 等待健康检查
        Write-Host ""
        Write-Host "等待健康检查 (最多60秒)..." -ForegroundColor Yellow
        for ($i = 1; $i -le 12; $i++) {
            $psOutput = docker compose ps | Out-String
            if ($psOutput -match "healthy") {
                Write-Host "✓ 服务健康检查通过" -ForegroundColor Green
                break
            }
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 5
        }
        Write-Host ""

        # 验证服务
        Write-Host ""
        Write-Host "验证服务..." -ForegroundColor Yellow

        # Config Server
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8888/actuator/health" -TimeoutSec 5 -ErrorAction Stop
            Write-Host "✓ Config Server 运行正常 - http://localhost:8888" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Config Server 可能仍在启动中" -ForegroundColor Yellow
        }

        # Test Application
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080/api/test/health" -TimeoutSec 5 -ErrorAction Stop
            Write-Host "✓ Test Application 运行正常 - http://localhost:8080" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Test Application 可能仍在启动中" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "部署完成！" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "访问地址:" -ForegroundColor Cyan
        Write-Host "  Config Server:     http://localhost:8888/actuator/health" -ForegroundColor Yellow
        Write-Host "  Test Application:  http://localhost:8080/api/test/health" -ForegroundColor Yellow
        Write-Host "  配置测试:          http://localhost:8080/api/test/config" -ForegroundColor Yellow
        Write-Host "  欢迎信息:          http://localhost:8080/api/test/welcome" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "常用命令:" -ForegroundColor Cyan
        Write-Host "  查看日志:   .\docker-deploy.ps1 logs" -ForegroundColor Yellow
        Write-Host "  停止服务:   .\docker-deploy.ps1 down" -ForegroundColor Yellow
        Write-Host "  重启服务:   .\docker-deploy.ps1 restart" -ForegroundColor Yellow
        Write-Host "  查看状态:   .\docker-deploy.ps1 status" -ForegroundColor Yellow
    }

    { $_ -in "down", "stop" } {
        Write-Host "停止服务..." -ForegroundColor Yellow
        docker compose down
        Write-Host "✓ 服务已停止" -ForegroundColor Green
    }

    "restart" {
        Write-Host "重启服务..." -ForegroundColor Yellow
        docker compose restart
        Write-Host "✓ 服务已重启" -ForegroundColor Green
    }

    "status" {
        Write-Host "服务状态:" -ForegroundColor Yellow
        docker compose ps
        Write-Host ""
        Write-Host "资源使用:" -ForegroundColor Yellow
        try {
            docker stats --no-stream platform-config platform-test
        } catch {
            Write-Host "服务未运行" -ForegroundColor Red
        }
    }

    "logs" {
        docker compose logs -f
    }

    "build" {
        Write-Host "重新构建镜像..." -ForegroundColor Yellow
        docker compose build --no-cache
        Write-Host "✓ 构建完成" -ForegroundColor Green
    }

    "clean" {
        Write-Host "清理所有资源..." -ForegroundColor Yellow
        docker compose down -v --rmi all
        Write-Host "✓ 清理完成" -ForegroundColor Green
    }

    "test" {
        Write-Host "测试 API 端点..." -ForegroundColor Yellow
        Write-Host ""

        Write-Host "1. Config Server 健康检查:" -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:8888/actuator/health"
            $response | ConvertTo-Json -Depth 10
        } catch {
            Write-Host "✗ 失败" -ForegroundColor Red
        }
        Write-Host ""

        Write-Host "2. Test Application 健康检查:" -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:8080/api/test/health"
            $response | ConvertTo-Json -Depth 10
        } catch {
            Write-Host "✗ 失败" -ForegroundColor Red
        }
        Write-Host ""

        Write-Host "3. 配置测试:" -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:8080/api/test/config"
            $response | ConvertTo-Json -Depth 10
        } catch {
            Write-Host "✗ 失败" -ForegroundColor Red
        }
        Write-Host ""

        Write-Host "4. 欢迎信息:" -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri "http://localhost:8080/api/test/welcome"
            $response | ConvertTo-Json -Depth 10
        } catch {
            Write-Host "✗ 失败" -ForegroundColor Red
        }
    }

    { $_ -in "help", "--help", "-h", "-?" } {
        Write-Host "用法: .\docker-deploy.ps1 [命令]"
        Write-Host ""
        Write-Host "命令:"
        Write-Host "  up, start    构建并启动服务 (默认)"
        Write-Host "  down, stop   停止服务"
        Write-Host "  restart      重启服务"
        Write-Host "  status       查看服务状态"
        Write-Host "  logs         查看实时日志"
        Write-Host "  build        重新构建镜像"
        Write-Host "  clean        清理所有资源"
        Write-Host "  test         测试 API 端点"
        Write-Host "  help         显示帮助信息"
        Write-Host ""
        Write-Host "环境变量:"
        Write-Host '  $env:GITLAB_TOKEN      GitLab 访问令牌'
        Write-Host '  $env:GITLAB_REPO_URL   GitLab 仓库 URL'
        Write-Host ""
        Write-Host "示例:"
        Write-Host "  .\docker-deploy.ps1           # 启动服务"
        Write-Host "  .\docker-deploy.ps1 logs      # 查看日志"
        Write-Host "  .\docker-deploy.ps1 test      # 测试 API"
        Write-Host "  .\docker-deploy.ps1 down      # 停止服务"
    }

    default {
        Write-Host "错误: 未知命令 '$Action'" -ForegroundColor Red
        Write-Host "使用 '.\docker-deploy.ps1 help' 查看帮助信息" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
