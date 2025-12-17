# 13 - Vue 前端设计

## 一、前端架构总览

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              前端技术栈                                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  核心框架:                       UI 组件库:                  工具库:                 │
│  ├── Vue 3.4+                    ├── Element Plus 2.x        ├── Axios              │
│  ├── TypeScript 5.x              ├── Tailwind CSS 3.x        ├── Day.js             │
│  ├── Vite 5.x                    └── ECharts 5.x             ├── Lodash-es          │
│  ├── Pinia 2.x                                               └── VueUse             │
│  └── Vue Router 4.x                                                                 │
│                                                                                     │
│  代码规范:                       构建部署:                   监控:                   │
│  ├── ESLint + Prettier           ├── Docker                  ├── Sentry             │
│  ├── Husky + lint-staged         ├── Nginx                   └── 性能监控           │
│  └── Commitlint                  └── CDN                                            │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、项目结构

```
platform-admin-frontend/
├── public/
│   └── favicon.ico
├── src/
│   ├── api/                        # API 接口
│   │   ├── modules/
│   │   │   ├── auth.ts             # 认证接口
│   │   │   ├── user.ts             # 用户接口
│   │   │   ├── role.ts             # 角色接口
│   │   │   ├── menu.ts             # 菜单接口
│   │   │   ├── dept.ts             # 部门接口
│   │   │   ├── dict.ts             # 字典接口
│   │   │   └── ...
│   │   ├── request.ts              # Axios 封装
│   │   └── index.ts                # 统一导出
│   │
│   ├── assets/                     # 静态资源
│   │   ├── images/
│   │   ├── icons/
│   │   └── styles/
│   │       ├── variables.scss      # SCSS 变量
│   │       ├── mixins.scss         # SCSS 混入
│   │       ├── element.scss        # Element Plus 覆盖
│   │       └── global.scss         # 全局样式
│   │
│   ├── components/                 # 公共组件
│   │   ├── common/
│   │   │   ├── SvgIcon/            # SVG 图标
│   │   │   ├── PageHeader/         # 页面标题
│   │   │   ├── SearchForm/         # 搜索表单
│   │   │   ├── TablePro/           # 增强表格
│   │   │   ├── FormPro/            # 增强表单
│   │   │   ├── UploadFile/         # 文件上传
│   │   │   ├── RichEditor/         # 富文本编辑
│   │   │   ├── CodeEditor/         # 代码编辑
│   │   │   ├── TreeSelect/         # 树形选择
│   │   │   └── DictTag/            # 字典标签
│   │   ├── business/
│   │   │   ├── UserSelect/         # 用户选择器
│   │   │   ├── DeptTree/           # 部门树
│   │   │   ├── RoleSelect/         # 角色选择器
│   │   │   └── PermSelect/         # 权限选择器
│   │   └── index.ts                # 全局注册
│   │
│   ├── composables/                # 组合式函数
│   │   ├── useTable.ts             # 表格逻辑
│   │   ├── useForm.ts              # 表单逻辑
│   │   ├── useDict.ts              # 字典逻辑
│   │   ├── usePermission.ts        # 权限逻辑
│   │   ├── useWebSocket.ts         # WebSocket
│   │   └── useECharts.ts           # 图表逻辑
│   │
│   ├── directives/                 # 自定义指令
│   │   ├── permission.ts           # 权限指令
│   │   ├── loading.ts              # 加载指令
│   │   ├── copy.ts                 # 复制指令
│   │   └── index.ts
│   │
│   ├── enums/                      # 枚举定义
│   │   ├── httpEnum.ts
│   │   ├── menuEnum.ts
│   │   └── commonEnum.ts
│   │
│   ├── hooks/                      # Vue Hooks
│   │   ├── useBoolean.ts
│   │   ├── useLoading.ts
│   │   └── useDebounce.ts
│   │
│   ├── layout/                     # 布局组件
│   │   ├── components/
│   │   │   ├── Header/
│   │   │   │   ├── index.vue
│   │   │   │   ├── UserInfo.vue
│   │   │   │   ├── Breadcrumb.vue
│   │   │   │   ├── Notice.vue
│   │   │   │   └── Setting.vue
│   │   │   ├── Sidebar/
│   │   │   │   ├── index.vue
│   │   │   │   ├── Logo.vue
│   │   │   │   └── MenuItem.vue
│   │   │   ├── TagsView/
│   │   │   │   └── index.vue
│   │   │   └── Footer/
│   │   │       └── index.vue
│   │   └── index.vue
│   │
│   ├── router/                     # 路由配置
│   │   ├── modules/                # 路由模块
│   │   │   ├── system.ts
│   │   │   ├── monitor.ts
│   │   │   └── ops.ts
│   │   ├── guards.ts               # 路由守卫
│   │   ├── routes.ts               # 静态路由
│   │   └── index.ts
│   │
│   ├── store/                      # 状态管理
│   │   ├── modules/
│   │   │   ├── user.ts             # 用户状态
│   │   │   ├── app.ts              # 应用状态
│   │   │   ├── permission.ts       # 权限状态
│   │   │   ├── tagsView.ts         # 标签页状态
│   │   │   └── dict.ts             # 字典状态
│   │   └── index.ts
│   │
│   ├── types/                      # 类型定义
│   │   ├── api.d.ts                # API 类型
│   │   ├── global.d.ts             # 全局类型
│   │   ├── router.d.ts             # 路由类型
│   │   └── env.d.ts                # 环境变量类型
│   │
│   ├── utils/                      # 工具函数
│   │   ├── auth.ts                 # 认证工具
│   │   ├── storage.ts              # 存储工具
│   │   ├── validate.ts             # 验证工具
│   │   ├── format.ts               # 格式化工具
│   │   └── tree.ts                 # 树形工具
│   │
│   ├── views/                      # 页面视图
│   │   ├── login/
│   │   │   └── index.vue
│   │   ├── dashboard/
│   │   │   ├── index.vue
│   │   │   └── components/
│   │   ├── system/                 # 系统管理
│   │   │   ├── user/
│   │   │   ├── role/
│   │   │   ├── menu/
│   │   │   ├── dept/
│   │   │   ├── post/
│   │   │   ├── dict/
│   │   │   └── config/
│   │   ├── monitor/                # 系统监控
│   │   │   ├── online/
│   │   │   ├── job/
│   │   │   ├── server/
│   │   │   └── cache/
│   │   ├── ops/                    # 运维管理
│   │   │   ├── service/
│   │   │   ├── deploy/
│   │   │   ├── config/
│   │   │   └── alert/
│   │   └── error/
│   │       ├── 403.vue
│   │       └── 404.vue
│   │
│   ├── App.vue
│   └── main.ts
│
├── .env                            # 环境变量
├── .env.development
├── .env.production
├── .eslintrc.cjs
├── .prettierrc
├── index.html
├── package.json
├── tsconfig.json
├── tailwind.config.js
└── vite.config.ts
```

## 三、核心配置

### 3.1 Vite 配置

```typescript
// vite.config.ts
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueJsx from '@vitejs/plugin-vue-jsx'
import { resolve } from 'path'
import AutoImport from 'unplugin-auto-import/vite'
import Components from 'unplugin-vue-components/vite'
import { ElementPlusResolver } from 'unplugin-vue-components/resolvers'
import { createSvgIconsPlugin } from 'vite-plugin-svg-icons'
import viteCompression from 'vite-plugin-compression'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd())

  return {
    plugins: [
      vue(),
      vueJsx(),

      // 自动导入
      AutoImport({
        imports: ['vue', 'vue-router', 'pinia', '@vueuse/core'],
        resolvers: [ElementPlusResolver()],
        dts: 'src/types/auto-imports.d.ts',
        eslintrc: {
          enabled: true
        }
      }),

      // 自动注册组件
      Components({
        resolvers: [ElementPlusResolver()],
        dts: 'src/types/components.d.ts',
        dirs: ['src/components']
      }),

      // SVG 图标
      createSvgIconsPlugin({
        iconDirs: [resolve(process.cwd(), 'src/assets/icons')],
        symbolId: 'icon-[dir]-[name]'
      }),

      // Gzip 压缩
      viteCompression({
        verbose: true,
        disable: false,
        threshold: 10240,
        algorithm: 'gzip',
        ext: '.gz'
      })
    ],

    resolve: {
      alias: {
        '@': resolve(__dirname, 'src')
      }
    },

    css: {
      preprocessorOptions: {
        scss: {
          additionalData: `@use "@/assets/styles/variables.scss" as *;`
        }
      }
    },

    server: {
      port: 3000,
      open: true,
      proxy: {
        '/api': {
          target: env.VITE_API_URL,
          changeOrigin: true
        },
        '/ws': {
          target: env.VITE_WS_URL,
          ws: true
        }
      }
    },

    build: {
      target: 'es2015',
      outDir: 'dist',
      assetsDir: 'assets',
      sourcemap: false,
      chunkSizeWarningLimit: 2000,
      rollupOptions: {
        output: {
          chunkFileNames: 'assets/js/[name]-[hash].js',
          entryFileNames: 'assets/js/[name]-[hash].js',
          assetFileNames: 'assets/[ext]/[name]-[hash].[ext]',
          manualChunks: {
            vue: ['vue', 'vue-router', 'pinia'],
            element: ['element-plus'],
            echarts: ['echarts'],
            vendor: ['axios', 'dayjs', 'lodash-es']
          }
        }
      },
      minify: 'terser',
      terserOptions: {
        compress: {
          drop_console: true,
          drop_debugger: true
        }
      }
    }
  }
})
```

### 3.2 环境变量

```bash
# .env.development
VITE_APP_TITLE=企业平台管理系统
VITE_APP_ENV=development
VITE_API_URL=http://localhost:8080
VITE_WS_URL=ws://localhost:8080
VITE_UPLOAD_URL=http://localhost:8080/api/files/upload

# .env.production
VITE_APP_TITLE=企业平台管理系统
VITE_APP_ENV=production
VITE_API_URL=https://api.platform.company.com
VITE_WS_URL=wss://api.platform.company.com
VITE_UPLOAD_URL=https://api.platform.company.com/api/files/upload
```

### 3.3 TypeScript 配置

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "module": "ESNext",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "preserve",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    },
    "types": ["vite/client", "element-plus/global"]
  },
  "include": ["src/**/*.ts", "src/**/*.d.ts", "src/**/*.tsx", "src/**/*.vue"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

## 四、Axios 封装

### 4.1 请求封装

```typescript
// src/api/request.ts
import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useUserStore } from '@/store/modules/user'
import router from '@/router'

// 响应数据结构
interface ApiResponse<T = any> {
  code: number
  data: T
  message: string
}

// 创建实例
const service: AxiosInstance = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// 请求拦截器
service.interceptors.request.use(
  (config) => {
    const userStore = useUserStore()

    // 添加 Token
    if (userStore.token) {
      config.headers.Authorization = `Bearer ${userStore.token}`
    }

    // 添加租户 ID
    if (userStore.tenantId) {
      config.headers['X-Tenant-Id'] = userStore.tenantId
    }

    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// 响应拦截器
service.interceptors.response.use(
  (response: AxiosResponse<ApiResponse>) => {
    const { code, message, data } = response.data

    // 成功
    if (code === 0) {
      return data
    }

    // Token 过期
    if (code === 401) {
      ElMessageBox.confirm('登录状态已过期，请重新登录', '提示', {
        confirmButtonText: '重新登录',
        cancelButtonText: '取消',
        type: 'warning'
      }).then(() => {
        const userStore = useUserStore()
        userStore.logout()
        router.push('/login')
      })
      return Promise.reject(new Error(message))
    }

    // 无权限
    if (code === 403) {
      router.push('/403')
      return Promise.reject(new Error(message))
    }

    // 其他错误
    ElMessage.error(message || '请求失败')
    return Promise.reject(new Error(message))
  },
  (error) => {
    const { response } = error

    if (response) {
      const { status, data } = response
      const message = data?.message || getErrorMessage(status)
      ElMessage.error(message)
    } else if (error.message.includes('timeout')) {
      ElMessage.error('请求超时，请稍后重试')
    } else if (error.message.includes('Network Error')) {
      ElMessage.error('网络异常，请检查网络连接')
    } else {
      ElMessage.error('请求失败')
    }

    return Promise.reject(error)
  }
)

// HTTP 状态码错误信息
function getErrorMessage(status: number): string {
  const messages: Record<number, string> = {
    400: '请求参数错误',
    401: '未授权，请登录',
    403: '拒绝访问',
    404: '资源不存在',
    500: '服务器内部错误',
    502: '网关错误',
    503: '服务不可用',
    504: '网关超时'
  }
  return messages[status] || `未知错误 (${status})`
}

// 封装请求方法
export function request<T = any>(config: AxiosRequestConfig): Promise<T> {
  return service(config) as Promise<T>
}

export function get<T = any>(url: string, params?: any, config?: AxiosRequestConfig): Promise<T> {
  return request({ url, method: 'GET', params, ...config })
}

export function post<T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
  return request({ url, method: 'POST', data, ...config })
}

export function put<T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> {
  return request({ url, method: 'PUT', data, ...config })
}

export function del<T = any>(url: string, params?: any, config?: AxiosRequestConfig): Promise<T> {
  return request({ url, method: 'DELETE', params, ...config })
}

export default service
```

### 4.2 API 模块示例

```typescript
// src/api/modules/user.ts
import { get, post, put, del } from '../request'

// 类型定义
export interface UserInfo {
  id: number
  username: string
  nickname: string
  email: string
  phone: string
  avatar: string
  deptId: number
  deptName: string
  roles: string[]
  permissions: string[]
}

export interface UserQuery {
  username?: string
  phone?: string
  status?: number
  deptId?: number
  pageNum: number
  pageSize: number
}

export interface UserForm {
  id?: number
  username: string
  nickname: string
  password?: string
  email: string
  phone: string
  deptId: number
  postIds: number[]
  roleIds: number[]
  status: number
  remark?: string
}

// API 接口
export const userApi = {
  // 获取用户列表
  list(query: UserQuery) {
    return get<PageResult<UserInfo>>('/api/users', query)
  },

  // 获取用户详情
  get(id: number) {
    return get<UserInfo>(`/api/users/${id}`)
  },

  // 创建用户
  create(data: UserForm) {
    return post<number>('/api/users', data)
  },

  // 更新用户
  update(id: number, data: UserForm) {
    return put<void>(`/api/users/${id}`, data)
  },

  // 删除用户
  delete(ids: number[]) {
    return del<void>('/api/users', { ids })
  },

  // 重置密码
  resetPassword(id: number) {
    return put<void>(`/api/users/${id}/password/reset`)
  },

  // 修改状态
  changeStatus(id: number, status: number) {
    return put<void>(`/api/users/${id}/status`, { status })
  },

  // 导出用户
  export(query: UserQuery) {
    return get('/api/users/export', query, { responseType: 'blob' })
  },

  // 导入模板
  importTemplate() {
    return get('/api/users/import/template', null, { responseType: 'blob' })
  }
}
```

## 五、状态管理

### 5.1 用户状态

```typescript
// src/store/modules/user.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi } from '@/api/modules/auth'
import { userApi, UserInfo } from '@/api/modules/user'
import { getToken, setToken, removeToken } from '@/utils/auth'
import router from '@/router'

export const useUserStore = defineStore('user', () => {
  // 状态
  const token = ref<string>(getToken() || '')
  const userInfo = ref<UserInfo | null>(null)
  const roles = ref<string[]>([])
  const permissions = ref<string[]>([])

  // 计算属性
  const isLoggedIn = computed(() => !!token.value)
  const username = computed(() => userInfo.value?.username || '')
  const avatar = computed(() => userInfo.value?.avatar || '/default-avatar.png')
  const tenantId = computed(() => userInfo.value?.tenantId)

  // 登录
  async function login(username: string, password: string) {
    const data = await authApi.login({ username, password })
    token.value = data.accessToken
    setToken(data.accessToken)
    return data
  }

  // 获取用户信息
  async function getUserInfo() {
    const data = await userApi.getCurrentUser()
    userInfo.value = data
    roles.value = data.roles
    permissions.value = data.permissions
    return data
  }

  // 退出登录
  async function logout() {
    try {
      await authApi.logout()
    } finally {
      resetState()
      router.push('/login')
    }
  }

  // 重置状态
  function resetState() {
    token.value = ''
    userInfo.value = null
    roles.value = []
    permissions.value = []
    removeToken()
  }

  // 检查权限
  function hasPermission(permission: string): boolean {
    if (permissions.value.includes('*:*:*')) {
      return true
    }
    return permissions.value.includes(permission)
  }

  // 检查角色
  function hasRole(role: string): boolean {
    return roles.value.includes(role)
  }

  return {
    // state
    token,
    userInfo,
    roles,
    permissions,
    // getters
    isLoggedIn,
    username,
    avatar,
    tenantId,
    // actions
    login,
    getUserInfo,
    logout,
    resetState,
    hasPermission,
    hasRole
  }
})
```

### 5.2 权限状态

```typescript
// src/store/modules/permission.ts
import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { RouteRecordRaw } from 'vue-router'
import { menuApi, MenuInfo } from '@/api/modules/menu'
import { constantRoutes } from '@/router/routes'
import Layout from '@/layout/index.vue'

// 视图组件映射
const viewModules = import.meta.glob('@/views/**/*.vue')

export const usePermissionStore = defineStore('permission', () => {
  // 完整路由
  const routes = ref<RouteRecordRaw[]>([])
  // 动态路由
  const dynamicRoutes = ref<RouteRecordRaw[]>([])
  // 菜单
  const menus = ref<MenuInfo[]>([])

  // 生成路由
  async function generateRoutes() {
    // 获取菜单
    const menuList = await menuApi.getRouters()
    menus.value = menuList

    // 转换为路由
    const asyncRoutes = transformMenuToRoutes(menuList)
    dynamicRoutes.value = asyncRoutes
    routes.value = constantRoutes.concat(asyncRoutes)

    return asyncRoutes
  }

  // 菜单转路由
  function transformMenuToRoutes(menus: MenuInfo[]): RouteRecordRaw[] {
    return menus.map((menu) => {
      const route: RouteRecordRaw = {
        path: menu.path,
        name: menu.name,
        meta: {
          title: menu.title,
          icon: menu.icon,
          hidden: menu.hidden,
          keepAlive: menu.keepAlive,
          permission: menu.permission
        }
      } as RouteRecordRaw

      // 布局组件
      if (menu.component === 'Layout') {
        route.component = Layout
      } else if (menu.component) {
        // 动态导入视图组件
        const componentPath = `/src/views/${menu.component}.vue`
        route.component = viewModules[componentPath]
      }

      // 递归处理子菜单
      if (menu.children && menu.children.length > 0) {
        route.children = transformMenuToRoutes(menu.children)
      }

      return route
    })
  }

  // 重置
  function resetRoutes() {
    routes.value = []
    dynamicRoutes.value = []
    menus.value = []
  }

  return {
    routes,
    dynamicRoutes,
    menus,
    generateRoutes,
    resetRoutes
  }
})
```

### 5.3 字典状态

```typescript
// src/store/modules/dict.ts
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { dictApi, DictData } from '@/api/modules/dict'

export const useDictStore = defineStore('dict', () => {
  // 字典缓存
  const dictCache = ref<Map<string, DictData[]>>(new Map())

  // 获取字典
  async function getDict(dictType: string): Promise<DictData[]> {
    // 缓存命中
    if (dictCache.value.has(dictType)) {
      return dictCache.value.get(dictType)!
    }

    // 请求数据
    const data = await dictApi.getData(dictType)
    dictCache.value.set(dictType, data)
    return data
  }

  // 批量获取
  async function getDicts(dictTypes: string[]): Promise<Record<string, DictData[]>> {
    const result: Record<string, DictData[]> = {}

    const needFetch: string[] = []
    for (const type of dictTypes) {
      if (dictCache.value.has(type)) {
        result[type] = dictCache.value.get(type)!
      } else {
        needFetch.push(type)
      }
    }

    if (needFetch.length > 0) {
      const data = await dictApi.getBatch(needFetch)
      for (const type of needFetch) {
        dictCache.value.set(type, data[type])
        result[type] = data[type]
      }
    }

    return result
  }

  // 获取标签
  function getDictLabel(dictType: string, value: string | number): string {
    const dict = dictCache.value.get(dictType)
    if (!dict) return String(value)

    const item = dict.find((d) => d.value === String(value))
    return item?.label || String(value)
  }

  // 刷新字典
  async function refreshDict(dictType: string) {
    dictCache.value.delete(dictType)
    await getDict(dictType)
  }

  // 清空缓存
  function clearCache() {
    dictCache.value.clear()
  }

  return {
    dictCache,
    getDict,
    getDicts,
    getDictLabel,
    refreshDict,
    clearCache
  }
})
```

## 六、组合式函数

### 6.1 表格 Hook

```typescript
// src/composables/useTable.ts
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'

interface UseTableOptions<T, Q> {
  api: (query: Q) => Promise<PageResult<T>>
  defaultQuery?: Partial<Q>
  immediate?: boolean
}

export function useTable<T = any, Q extends PageQuery = PageQuery>(options: UseTableOptions<T, Q>) {
  const { api, defaultQuery = {}, immediate = true } = options

  // 状态
  const loading = ref(false)
  const tableData = ref<T[]>([])
  const total = ref(0)
  const selectedRows = ref<T[]>([])

  // 查询参数
  const query = reactive<Q>({
    pageNum: 1,
    pageSize: 10,
    ...defaultQuery
  } as Q)

  // 加载数据
  async function loadData() {
    try {
      loading.value = true
      const { list, total: count } = await api(query)
      tableData.value = list
      total.value = count
    } finally {
      loading.value = false
    }
  }

  // 搜索
  function search() {
    query.pageNum = 1
    loadData()
  }

  // 重置
  function reset() {
    Object.assign(query, {
      pageNum: 1,
      pageSize: 10,
      ...defaultQuery
    })
    loadData()
  }

  // 分页变化
  function handlePageChange(page: number) {
    query.pageNum = page
    loadData()
  }

  // 每页数量变化
  function handleSizeChange(size: number) {
    query.pageNum = 1
    query.pageSize = size
    loadData()
  }

  // 选择变化
  function handleSelectionChange(rows: T[]) {
    selectedRows.value = rows
  }

  // 删除确认
  async function confirmDelete(
    ids: number[],
    deleteApi: (ids: number[]) => Promise<void>,
    message = '确认删除选中的数据吗？'
  ) {
    await ElMessageBox.confirm(message, '提示', {
      type: 'warning',
      confirmButtonText: '确定',
      cancelButtonText: '取消'
    })

    await deleteApi(ids)
    ElMessage.success('删除成功')
    loadData()
  }

  // 初始加载
  if (immediate) {
    onMounted(loadData)
  }

  return {
    loading,
    tableData,
    total,
    selectedRows,
    query,
    loadData,
    search,
    reset,
    handlePageChange,
    handleSizeChange,
    handleSelectionChange,
    confirmDelete
  }
}
```

### 6.2 表单 Hook

```typescript
// src/composables/useForm.ts
import { ref, reactive, Ref } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { ElMessage } from 'element-plus'

interface UseFormOptions<T> {
  defaultValues: T
  rules?: FormRules
  createApi?: (data: T) => Promise<any>
  updateApi?: (id: number, data: T) => Promise<any>
  afterSubmit?: () => void
}

export function useForm<T extends Record<string, any>>(options: UseFormOptions<T>) {
  const { defaultValues, rules = {}, createApi, updateApi, afterSubmit } = options

  // 状态
  const visible = ref(false)
  const isEdit = ref(false)
  const loading = ref(false)
  const formRef = ref<FormInstance>()
  const formData = reactive<T>({ ...defaultValues }) as T

  // 打开新增
  function openAdd() {
    isEdit.value = false
    resetForm()
    visible.value = true
  }

  // 打开编辑
  function openEdit(row: T) {
    isEdit.value = true
    Object.assign(formData, row)
    visible.value = true
  }

  // 关闭
  function close() {
    visible.value = false
    resetForm()
  }

  // 重置表单
  function resetForm() {
    Object.assign(formData, defaultValues)
    formRef.value?.resetFields()
  }

  // 提交
  async function submit() {
    const valid = await formRef.value?.validate()
    if (!valid) return

    try {
      loading.value = true

      if (isEdit.value) {
        await updateApi?.(formData.id, formData)
        ElMessage.success('修改成功')
      } else {
        await createApi?.(formData)
        ElMessage.success('新增成功')
      }

      close()
      afterSubmit?.()
    } finally {
      loading.value = false
    }
  }

  return {
    visible,
    isEdit,
    loading,
    formRef,
    formData,
    rules,
    openAdd,
    openEdit,
    close,
    submit
  }
}
```

### 6.3 字典 Hook

```typescript
// src/composables/useDict.ts
import { ref, onMounted } from 'vue'
import { useDictStore } from '@/store/modules/dict'

export function useDict(...dictTypes: string[]) {
  const dictStore = useDictStore()
  const dicts = ref<Record<string, DictData[]>>({})
  const loading = ref(false)

  // 加载字典
  async function loadDicts() {
    loading.value = true
    try {
      dicts.value = await dictStore.getDicts(dictTypes)
    } finally {
      loading.value = false
    }
  }

  // 获取选项
  function getOptions(dictType: string) {
    return dicts.value[dictType] || []
  }

  // 获取标签
  function getLabel(dictType: string, value: string | number) {
    return dictStore.getDictLabel(dictType, value)
  }

  // 初始化
  onMounted(loadDicts)

  return {
    dicts,
    loading,
    getOptions,
    getLabel
  }
}
```

## 七、公共组件

### 7.1 增强表格

```vue
<!-- src/components/common/TablePro/index.vue -->
<template>
  <div class="table-pro">
    <!-- 工具栏 -->
    <div class="table-toolbar" v-if="$slots.toolbar || showToolbar">
      <div class="toolbar-left">
        <slot name="toolbar">
          <el-button type="primary" @click="$emit('add')" v-if="showAdd" v-permission="addPermission">
            <el-icon><Plus /></el-icon>
            新增
          </el-button>
          <el-button type="danger" @click="$emit('delete')" v-if="showDelete" :disabled="!selectedRows.length" v-permission="deletePermission">
            <el-icon><Delete /></el-icon>
            删除
          </el-button>
          <el-button @click="$emit('export')" v-if="showExport" v-permission="exportPermission">
            <el-icon><Download /></el-icon>
            导出
          </el-button>
        </slot>
      </div>
      <div class="toolbar-right">
        <el-button-group>
          <el-button @click="handleRefresh">
            <el-icon><Refresh /></el-icon>
          </el-button>
          <el-button @click="handleColumnSetting">
            <el-icon><Setting /></el-icon>
          </el-button>
        </el-button-group>
      </div>
    </div>

    <!-- 表格 -->
    <el-table
      ref="tableRef"
      v-loading="loading"
      :data="data"
      :row-key="rowKey"
      :border="border"
      :stripe="stripe"
      @selection-change="handleSelectionChange"
      v-bind="$attrs"
    >
      <el-table-column type="selection" width="55" v-if="showSelection" />
      <el-table-column type="index" label="序号" width="60" v-if="showIndex" />

      <slot />

      <!-- 操作列 -->
      <el-table-column label="操作" :width="actionWidth" fixed="right" v-if="$slots.action">
        <template #default="scope">
          <slot name="action" v-bind="scope" />
        </template>
      </el-table-column>
    </el-table>

    <!-- 分页 -->
    <div class="table-pagination" v-if="showPagination">
      <el-pagination
        v-model:current-page="currentPage"
        v-model:page-size="pageSize"
        :page-sizes="pageSizes"
        :total="total"
        layout="total, sizes, prev, pager, next, jumper"
        @size-change="handleSizeChange"
        @current-change="handleCurrentChange"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

const props = withDefaults(
  defineProps<{
    data: any[]
    loading?: boolean
    total?: number
    rowKey?: string
    border?: boolean
    stripe?: boolean
    showToolbar?: boolean
    showSelection?: boolean
    showIndex?: boolean
    showPagination?: boolean
    showAdd?: boolean
    showDelete?: boolean
    showExport?: boolean
    addPermission?: string
    deletePermission?: string
    exportPermission?: string
    actionWidth?: number
    pageSizes?: number[]
  }>(),
  {
    loading: false,
    total: 0,
    rowKey: 'id',
    border: true,
    stripe: true,
    showToolbar: true,
    showSelection: true,
    showIndex: true,
    showPagination: true,
    showAdd: true,
    showDelete: true,
    showExport: false,
    actionWidth: 200,
    pageSizes: () => [10, 20, 50, 100]
  }
)

const emit = defineEmits<{
  add: []
  delete: []
  export: []
  refresh: []
  'update:page': [page: number]
  'update:size': [size: number]
  'selection-change': [rows: any[]]
}>()

const tableRef = ref()
const currentPage = ref(1)
const pageSize = ref(10)
const selectedRows = ref<any[]>([])

function handleSelectionChange(rows: any[]) {
  selectedRows.value = rows
  emit('selection-change', rows)
}

function handleCurrentChange(page: number) {
  emit('update:page', page)
}

function handleSizeChange(size: number) {
  emit('update:size', size)
}

function handleRefresh() {
  emit('refresh')
}

function handleColumnSetting() {
  // 列设置弹窗
}
</script>

<style lang="scss" scoped>
.table-pro {
  .table-toolbar {
    display: flex;
    justify-content: space-between;
    margin-bottom: 16px;
  }

  .table-pagination {
    display: flex;
    justify-content: flex-end;
    margin-top: 16px;
  }
}
</style>
```

### 7.2 字典标签

```vue
<!-- src/components/common/DictTag/index.vue -->
<template>
  <el-tag v-if="dictItem" :type="tagType" :effect="effect">
    {{ dictItem.label }}
  </el-tag>
  <span v-else>{{ value }}</span>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useDictStore } from '@/store/modules/dict'

const props = defineProps<{
  type: string
  value: string | number
  effect?: 'dark' | 'light' | 'plain'
}>()

const dictStore = useDictStore()

const dictItem = computed(() => {
  const dict = dictStore.dictCache.get(props.type)
  return dict?.find((d) => d.value === String(props.value))
})

const tagType = computed(() => {
  return dictItem.value?.listClass || ''
})
</script>
```

## 八、权限控制

### 8.1 权限指令

```typescript
// src/directives/permission.ts
import type { Directive, DirectiveBinding } from 'vue'
import { useUserStore } from '@/store/modules/user'

export const permission: Directive = {
  mounted(el: HTMLElement, binding: DirectiveBinding) {
    const { value } = binding
    const userStore = useUserStore()

    if (value) {
      const hasPermission = userStore.hasPermission(value)
      if (!hasPermission) {
        el.parentNode?.removeChild(el)
      }
    }
  }
}

// 注册
// main.ts
app.directive('permission', permission)

// 使用
// <el-button v-permission="'user:add'">新增</el-button>
```

### 8.2 路由守卫

```typescript
// src/router/guards.ts
import type { Router } from 'vue-router'
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import { useUserStore } from '@/store/modules/user'
import { usePermissionStore } from '@/store/modules/permission'

// 白名单
const whiteList = ['/login', '/register', '/404', '/403']

export function setupRouterGuards(router: Router) {
  router.beforeEach(async (to, from, next) => {
    NProgress.start()

    const userStore = useUserStore()
    const permissionStore = usePermissionStore()

    // 已登录
    if (userStore.token) {
      if (to.path === '/login') {
        next({ path: '/' })
        return
      }

      // 已加载用户信息
      if (userStore.userInfo) {
        next()
        return
      }

      try {
        // 获取用户信息
        await userStore.getUserInfo()
        // 生成动态路由
        const routes = await permissionStore.generateRoutes()
        // 添加路由
        routes.forEach((route) => router.addRoute(route))
        // 添加 404
        router.addRoute({ path: '/:pathMatch(.*)*', redirect: '/404' })
        // 重定向
        next({ ...to, replace: true })
      } catch (error) {
        userStore.resetState()
        next(`/login?redirect=${to.path}`)
      }
    } else {
      // 未登录
      if (whiteList.includes(to.path)) {
        next()
      } else {
        next(`/login?redirect=${to.path}`)
      }
    }
  })

  router.afterEach(() => {
    NProgress.done()
  })
}
```

## 九、页面示例

### 9.1 用户管理页面

```vue
<!-- src/views/system/user/index.vue -->
<template>
  <div class="user-page">
    <!-- 搜索表单 -->
    <el-card class="search-card">
      <el-form :model="query" inline>
        <el-form-item label="用户名">
          <el-input v-model="query.username" placeholder="请输入用户名" clearable />
        </el-form-item>
        <el-form-item label="手机号">
          <el-input v-model="query.phone" placeholder="请输入手机号" clearable />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="query.status" placeholder="请选择" clearable>
            <el-option
              v-for="item in getOptions('sys_common_status')"
              :key="item.value"
              :label="item.label"
              :value="item.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="部门">
          <dept-tree-select v-model="query.deptId" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="search">
            <el-icon><Search /></el-icon>
            搜索
          </el-button>
          <el-button @click="reset">
            <el-icon><Refresh /></el-icon>
            重置
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 数据表格 -->
    <el-card class="table-card">
      <table-pro
        :data="tableData"
        :loading="loading"
        :total="total"
        add-permission="user:add"
        delete-permission="user:delete"
        @add="handleAdd"
        @delete="handleBatchDelete"
        @refresh="loadData"
        @update:page="handlePageChange"
        @update:size="handleSizeChange"
        @selection-change="handleSelectionChange"
      >
        <el-table-column prop="username" label="用户名" />
        <el-table-column prop="nickname" label="昵称" />
        <el-table-column prop="deptName" label="部门" />
        <el-table-column prop="phone" label="手机号" />
        <el-table-column prop="status" label="状态">
          <template #default="{ row }">
            <el-switch
              v-model="row.status"
              :active-value="1"
              :inactive-value="0"
              @change="handleStatusChange(row)"
            />
          </template>
        </el-table-column>
        <el-table-column prop="createTime" label="创建时间" width="180" />

        <template #action="{ row }">
          <el-button link type="primary" @click="handleEdit(row)" v-permission="'user:edit'">
            编辑
          </el-button>
          <el-button link type="primary" @click="handleResetPwd(row)" v-permission="'user:resetPwd'">
            重置密码
          </el-button>
          <el-button link type="danger" @click="handleDelete(row)" v-permission="'user:delete'">
            删除
          </el-button>
        </template>
      </table-pro>
    </el-card>

    <!-- 新增/编辑弹窗 -->
    <user-form ref="formRef" @success="loadData" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { userApi, UserInfo, UserQuery } from '@/api/modules/user'
import { useTable } from '@/composables/useTable'
import { useDict } from '@/composables/useDict'
import UserForm from './components/UserForm.vue'

// 字典
const { getOptions } = useDict('sys_common_status')

// 表格
const {
  loading,
  tableData,
  total,
  selectedRows,
  query,
  loadData,
  search,
  reset,
  handlePageChange,
  handleSizeChange,
  handleSelectionChange
} = useTable<UserInfo, UserQuery>({
  api: userApi.list,
  defaultQuery: {
    username: '',
    phone: '',
    status: undefined,
    deptId: undefined
  }
})

// 表单
const formRef = ref()

// 新增
function handleAdd() {
  formRef.value?.open()
}

// 编辑
function handleEdit(row: UserInfo) {
  formRef.value?.open(row.id)
}

// 删除
async function handleDelete(row: UserInfo) {
  await ElMessageBox.confirm(`确认删除用户 "${row.username}" 吗？`, '提示', {
    type: 'warning'
  })
  await userApi.delete([row.id])
  ElMessage.success('删除成功')
  loadData()
}

// 批量删除
async function handleBatchDelete() {
  if (selectedRows.value.length === 0) {
    ElMessage.warning('请选择要删除的数据')
    return
  }
  await ElMessageBox.confirm(`确认删除选中的 ${selectedRows.value.length} 条数据吗？`, '提示', {
    type: 'warning'
  })
  const ids = selectedRows.value.map((row) => row.id)
  await userApi.delete(ids)
  ElMessage.success('删除成功')
  loadData()
}

// 重置密码
async function handleResetPwd(row: UserInfo) {
  await ElMessageBox.confirm(`确认重置用户 "${row.username}" 的密码吗？`, '提示', {
    type: 'warning'
  })
  await userApi.resetPassword(row.id)
  ElMessage.success('密码已重置为默认密码')
}

// 修改状态
async function handleStatusChange(row: UserInfo) {
  try {
    await userApi.changeStatus(row.id, row.status)
    ElMessage.success('状态修改成功')
  } catch {
    row.status = row.status === 1 ? 0 : 1
  }
}
</script>

<style lang="scss" scoped>
.user-page {
  .search-card {
    margin-bottom: 16px;
  }
}
</style>
```

## 十、构建部署

### 10.1 Dockerfile

```dockerfile
# Dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### 10.2 Nginx 配置

```nginx
# nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # 静态资源缓存
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # API 代理
        location /api/ {
            proxy_pass http://gateway:8080/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # WebSocket 代理
        location /ws/ {
            proxy_pass http://gateway:8080/ws/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # SPA 路由
        location / {
            try_files $uri $uri/ /index.html;
        }

        # 健康检查
        location /health {
            return 200 'OK';
            add_header Content-Type text/plain;
        }
    }
}
```
