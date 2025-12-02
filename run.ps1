# Platform项目运行脚本 (PowerShell)
# 用于在Windows上启动Spring Boot应用

param(
    [switch]$Help,
    [switch]$ConfigOnly,
    [switch]$TestOnly,
    [switch]$Remote
)

# 配置
$GITLAB_TOKEN = $env:GITLAB_TOKEN
$GITLAB_REPO_URL = $env:GITLAB_REPO_URL

if (-not $GITLAB_TOKEN) {
    $GITLAB_TOKEN = "your-gitlab-token-here"
}
if (-not $GITLAB_REPO_URL) {
    $GITLAB_REPO_URL = "http://192.168.0.99:8929/xz01/springconfig.git"
}

# 帮助信息
if ($Help) {
    Write-Host "Platform项目运行脚本" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "用法:" -ForegroundColor Yellow
    Write-Host "  .\run.ps1              # 运行所有服务"
    Write-Host "  .\run.ps1 -ConfigOnly  # 仅运行Config Server"
    Write-Host "  .\run.ps1 -TestOnly    # 仅运行Test Application"
    Write-Host "  .\run.ps1 -Remote      # 部署到远程服务器"
    Write-Host ""
    Write-Host "环境变量:" -ForegroundColor Yellow
    Write-Host "  GITLAB_TOKEN     GitLab访问令牌"
    Write-Host "  GITLAB_REPO_URL  GitLab仓库URL"
    Write-Host ""
    Write-Host "示例:" -ForegroundColor Yellow
    Write-Host '  $env:GITLAB_TOKEN="your-token"'
    Write-Host '  .\run.ps1'
    exit 0
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Platform项目启动" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 设置环境变量
$env:GITLAB_TOKEN = $GITLAB_TOKEN
$env:GITLAB_REPO_URL = $GITLAB_REPO_URL

Write-Host "配置信息:" -ForegroundColor Yellow
Write-Host "  GitLab URL: $GITLAB_REPO_URL" -ForegroundColor Gray
Write-Host "  Token: $($GITLAB_TOKEN.Substring(0,15))..." -ForegroundColor Gray
Write-Host ""

# 检查Maven
$mvnPath = Get-Command mvn -ErrorAction SilentlyContinue
if (-not $mvnPath) {
    Write-Host "警告: Maven未在PATH中找到" -ForegroundColor Yellow
    Write-Host "将尝试使用IntelliJ IDEA内置Maven..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "请在IntelliJ IDEA中运行:" -ForegroundColor Cyan
    Write-Host "  1. 打开 platform-config/src/main/java/com/platform/config/ConfigServerApplication.java" -ForegroundColor White
    Write-Host "  2. 右键 -> Run 'ConfigServerApplication'" -ForegroundColor White
    Write-Host "  3. 等待30秒" -ForegroundColor White
    Write-Host "  4. 打开 platform-test/src/main/java/com/platform/test/TestApplication.java" -ForegroundColor White
    Write-Host "  5. 右键 -> Run 'TestApplication'" -ForegroundColor White
    Write-Host ""
    Write-Host "或者安装Maven后再运行此脚本" -ForegroundColor Yellow
    exit 1
}

# 远程部署
if ($Remote) {
    Write-Host "正在部署到远程服务器..." -ForegroundColor Yellow
    bash deploy-and-run.sh --remote
    exit 0
}

# 运行Config Server
if (-not $TestOnly) {
    Write-Host "[1/2] 启动Config Server..." -ForegroundColor Yellow
    Write-Host "  端口: 8888" -ForegroundColor Gray
    Write-Host "  日志: config-server.log" -ForegroundColor Gray

    Start-Process powershell -ArgumentList `
        "-NoExit", `
        "-Command", `
        "Set-Location platform-config; " +
        "`$env:GITLAB_TOKEN='$GITLAB_TOKEN'; " +
        "`$env:GITLAB_REPO_URL='$GITLAB_REPO_URL'; " +
        "Write-Host 'Config Server Starting...' -ForegroundColor Green; " +
        "mvn spring-boot:run"

    if (-not $ConfigOnly) {
        Write-Host "  等待Config Server启动..." -ForegroundColor Gray
        Start-Sleep -Seconds 30
    }
}

# 运行Test Application
if (-not $ConfigOnly) {
    Write-Host ""
    Write-Host "[2/2] 启动Test Application..." -ForegroundColor Yellow
    Write-Host "  端口: 8080" -ForegroundColor Gray
    Write-Host "  日志: test-app.log" -ForegroundColor Gray

    Start-Process powershell -ArgumentList `
        "-NoExit", `
        "-Command", `
        "Set-Location platform-test; " +
        "Write-Host 'Test Application Starting...' -ForegroundColor Green; " +
        "mvn spring-boot:run"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "服务正在启动..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (-not $TestOnly) {
    Write-Host "Config Server:" -ForegroundColor Cyan
    Write-Host "  URL: http://localhost:8888" -ForegroundColor White
    Write-Host "  健康检查: http://localhost:8888/actuator/health" -ForegroundColor Gray
}

if (-not $ConfigOnly) {
    Write-Host ""
    Write-Host "Test Application:" -ForegroundColor Cyan
    Write-Host "  URL: http://localhost:8080" -ForegroundColor White
    Write-Host "  健康检查: http://localhost:8080/api/test/health" -ForegroundColor Gray
    Write-Host "  配置测试: http://localhost:8080/api/test/config" -ForegroundColor Gray
    Write-Host "  欢迎信息: http://localhost:8080/api/test/welcome" -ForegroundColor Gray
}

Write-Host ""
Write-Host "提示:" -ForegroundColor Yellow
Write-Host "  - 等待约30秒后访问上述URL" -ForegroundColor Gray
Write-Host "  - 关闭PowerShell窗口将停止对应服务" -ForegroundColor Gray
Write-Host "  - 查看各窗口的日志以了解启动状态" -ForegroundColor Gray
Write-Host ""

# 等待用户输入
Write-Host "按任意键验证服务..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "验证服务状态..." -ForegroundColor Yellow

# 验证Config Server
if (-not $TestOnly) {
    try {
        Start-Sleep -Seconds 5
        $response = Invoke-WebRequest -Uri "http://localhost:8888/actuator/health" -TimeoutSec 5
        Write-Host "✓ Config Server 运行正常" -ForegroundColor Green
    } catch {
        Write-Host "✗ Config Server 未就绪 (可能仍在启动中)" -ForegroundColor Yellow
    }
}

# 验证Test Application
if (-not $ConfigOnly) {
    try {
        Start-Sleep -Seconds 5
        $response = Invoke-WebRequest -Uri "http://localhost:8080/api/test/health" -TimeoutSec 5
        Write-Host "✓ Test Application 运行正常" -ForegroundColor Green

        # 显示响应
        $json = $response.Content | ConvertFrom-Json
        Write-Host ""
        Write-Host "响应数据:" -ForegroundColor Cyan
        Write-Host ($json | ConvertTo-Json -Depth 10) -ForegroundColor Gray
    } catch {
        Write-Host "✗ Test Application 未就绪 (可能仍在启动中)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "启动完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
