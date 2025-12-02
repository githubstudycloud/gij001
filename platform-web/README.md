# Platform Web - 配置中心管理界面

基于 Vue 3 + Vite + Element Plus 的配置中心管理界面。

## 技术栈

- **Vue 3** - 渐进式 JavaScript 框架
- **Vite** - 下一代前端构建工具
- **Element Plus** - Vue 3 组件库
- **Axios** - HTTP 请求库

## 功能特性

- ✅ 配置查询 - 按应用、环境、分支查询配置
- ✅ 配置搜索 - 关键词搜索配置项
- ✅ 配置键查询 - 查询指定配置键的值
- ✅ 配置导出 - 导出配置为 JSON 文件
- ✅ 缓存刷新 - 刷新配置服务器缓存
- ✅ 健康检查 - 检查配置服务器状态

## 快速开始

### 1. 安装依赖

```bash
cd platform-web
npm install
```

### 2. 启动开发服务器

```bash
npm run dev
```

默认访问地址：http://localhost:3000

### 3. 构建生产版本

```bash
npm run build
```

### 4. 预览生产构建

```bash
npm run preview
```

## 配置说明

### 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| VITE_API_BASE_URL | API 服务器地址 | http://localhost:8888 |

### 开发环境配置

编辑 `.env.development`:

```
VITE_API_BASE_URL=http://localhost:8888
```

### 生产环境配置

编辑 `.env.production`:

```
VITE_API_BASE_URL=/api
```

## 目录结构

```
platform-web/
├── public/              # 静态资源
├── src/
│   ├── api/            # API 接口定义
│   │   └── config.js   # 配置管理接口
│   ├── assets/         # 资源文件
│   ├── components/     # 公共组件
│   ├── views/          # 页面组件
│   │   └── ConfigManager.vue  # 配置管理页面
│   ├── App.vue         # 根组件
│   ├── main.js         # 入口文件
│   └── style.css       # 全局样式
├── .env.development    # 开发环境变量
├── .env.production     # 生产环境变量
├── index.html          # HTML 模板
├── package.json        # 项目配置
├── vite.config.js      # Vite 配置
└── README.md           # 项目说明
```

## API 接口

### 配置管理接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/config/{app}/{profile}` | 获取配置 |
| GET | `/api/config/{app}/{profile}/{label}` | 获取指定分支配置 |
| GET | `/api/config/sources/{app}/{profile}/{label}` | 获取配置源列表 |
| GET | `/api/config/value/{app}/{profile}/{label}?key=xxx` | 获取配置值 |
| GET | `/api/config/search/{app}/{profile}/{label}?keyword=xxx` | 搜索配置 |
| POST | `/api/config/refresh` | 刷新缓存 |
| GET | `/api/config/health` | 健康检查 |

## 使用说明

### 1. 启动后端服务

确保 Config Server 已启动（默认端口 8888）：

```bash
cd platform-config
mvn spring-boot:run
```

### 2. 配置 GitLab Token

设置环境变量：

```bash
# Windows
set GITLAB_TOKEN=your_token

# Linux/macOS
export GITLAB_TOKEN=your_token
```

### 3. 查询配置

1. 输入应用名称（如：platform-test）
2. 选择环境（dev/test/prod）
3. 输入分支名（默认 main）
4. 点击"查询配置"按钮

### 4. 搜索配置

在"搜索关键词"输入框中输入关键词，点击搜索按钮。

### 5. 导出配置

查询配置后，点击"导出"按钮可将配置导出为 JSON 文件。

## 注意事项

1. **跨域问题**: 开发模式下通过 Vite 代理解决跨域，生产环境需要后端配置 CORS 或使用 Nginx 反向代理
2. **GitLab 认证**: 确保 Config Server 已正确配置 GitLab 访问令牌
3. **配置仓库**: 确保 GitLab 配置仓库中存在对应的配置文件

## 常见问题

### Q: 无法连接到配置服务器

A: 检查以下项目：
- Config Server 是否已启动
- 端口是否正确（默认 8888）
- 防火墙是否允许访问

### Q: 获取配置失败

A: 检查以下项目：
- 应用名称和环境是否正确
- GitLab 配置仓库中是否存在对应的配置文件
- GitLab Token 是否有效

### Q: 跨域错误

A: 开发模式下检查 vite.config.js 中的代理配置，生产环境需要后端配置 CORS。

## 更新日志

### v1.0.0 (2025-12-02)

- 初始版本
- 实现配置查询、搜索、导出功能
- 支持健康检查和缓存刷新
