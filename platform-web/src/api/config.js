import axios from 'axios'

// 创建 axios 实例
const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8888',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// 请求拦截器
api.interceptors.request.use(
  config => {
    console.log('请求:', config.method?.toUpperCase(), config.url)
    return config
  },
  error => {
    console.error('请求错误:', error)
    return Promise.reject(error)
  }
)

// 响应拦截器
api.interceptors.response.use(
  response => {
    console.log('响应:', response.status, response.config.url)
    return response.data
  },
  error => {
    console.error('响应错误:', error.response?.status, error.message)
    return Promise.reject(error)
  }
)

/**
 * 配置管理 API
 */
export const configApi = {
  /**
   * 获取配置
   * @param {string} application - 应用名称
   * @param {string} profile - 环境
   * @param {string} label - 分支（可选）
   */
  getConfig(application, profile, label = 'main') {
    return api.get(`/api/config/${application}/${profile}/${label}`)
  },

  /**
   * 获取配置源列表
   */
  getConfigSources(application, profile, label = 'main') {
    return api.get(`/api/config/sources/${application}/${profile}/${label}`)
  },

  /**
   * 获取指定配置键的值
   */
  getConfigValue(application, profile, label, key) {
    return api.get(`/api/config/value/${application}/${profile}/${label}`, {
      params: { key }
    })
  },

  /**
   * 搜索配置
   */
  searchConfig(application, profile, label, keyword) {
    return api.get(`/api/config/search/${application}/${profile}/${label}`, {
      params: { keyword }
    })
  },

  /**
   * 刷新配置缓存
   */
  refreshConfig() {
    return api.post('/api/config/refresh')
  },

  /**
   * 健康检查
   */
  health() {
    return api.get('/api/config/health')
  }
}

/**
 * Spring Cloud Config Server 原生 API
 */
export const configServerApi = {
  /**
   * 获取配置（YAML 格式）
   */
  getConfigYaml(application, profile, label = 'main') {
    return api.get(`/${application}-${profile}.yml`, {
      params: { label },
      transformResponse: [data => data] // 保持原始文本
    })
  },

  /**
   * 获取配置（Properties 格式）
   */
  getConfigProperties(application, profile, label = 'main') {
    return api.get(`/${application}-${profile}.properties`, {
      params: { label },
      transformResponse: [data => data]
    })
  },

  /**
   * 获取配置（JSON 格式）
   */
  getConfigJson(application, profile, label = 'main') {
    return api.get(`/${application}/${profile}/${label}`)
  }
}

export default api
