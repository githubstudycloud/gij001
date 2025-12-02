<template>
  <div class="config-manager">
    <!-- 页面标题 -->
    <el-card class="header-card">
      <template #header>
        <div class="header-content">
          <span class="title">
            <el-icon><Setting /></el-icon>
            配置中心管理
          </span>
          <el-button type="success" :icon="Refresh" @click="checkHealth" :loading="healthLoading">
            健康检查
          </el-button>
        </div>
      </template>

      <!-- 健康状态 -->
      <el-tag v-if="healthStatus" :type="healthStatus.status === 'UP' ? 'success' : 'danger'" size="large">
        服务状态: {{ healthStatus.status }}
      </el-tag>
    </el-card>

    <!-- 查询表单 -->
    <el-card class="query-card">
      <template #header>
        <span><el-icon><Search /></el-icon> 配置查询</span>
      </template>

      <el-form :model="queryForm" label-width="100px" class="query-form">
        <el-row :gutter="20">
          <el-col :span="6">
            <el-form-item label="应用名称">
              <el-input v-model="queryForm.application" placeholder="如: platform-test" clearable />
            </el-form-item>
          </el-col>
          <el-col :span="6">
            <el-form-item label="环境">
              <el-select v-model="queryForm.profile" placeholder="选择环境" clearable>
                <el-option label="开发环境 (dev)" value="dev" />
                <el-option label="测试环境 (test)" value="test" />
                <el-option label="预发布 (staging)" value="staging" />
                <el-option label="生产环境 (prod)" value="prod" />
                <el-option label="默认 (default)" value="default" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="6">
            <el-form-item label="分支">
              <el-input v-model="queryForm.label" placeholder="如: main" clearable />
            </el-form-item>
          </el-col>
          <el-col :span="6">
            <el-form-item label="">
              <el-button type="primary" :icon="Search" @click="fetchConfig" :loading="loading">
                查询配置
              </el-button>
              <el-button :icon="Refresh" @click="refreshConfigCache" :loading="refreshLoading">
                刷新缓存
              </el-button>
            </el-form-item>
          </el-col>
        </el-row>

        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="搜索关键词">
              <el-input v-model="queryForm.keyword" placeholder="输入关键词搜索配置" clearable>
                <template #append>
                  <el-button :icon="Search" @click="searchConfigByKeyword" :loading="searchLoading" />
                </template>
              </el-input>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="指定配置键">
              <el-input v-model="queryForm.configKey" placeholder="输入配置键获取值" clearable>
                <template #append>
                  <el-button :icon="Search" @click="getConfigByKey" :loading="keyLoading" />
                </template>
              </el-input>
            </el-form-item>
          </el-col>
        </el-row>
      </el-form>
    </el-card>

    <!-- 配置结果 -->
    <el-row :gutter="20" class="result-row">
      <!-- 配置属性表格 -->
      <el-col :span="16">
        <el-card class="result-card">
          <template #header>
            <div class="result-header">
              <span><el-icon><Document /></el-icon> 配置属性 ({{ configData.length }} 项)</span>
              <div class="result-actions">
                <el-input
                  v-model="filterText"
                  placeholder="过滤配置项"
                  :prefix-icon="Search"
                  clearable
                  style="width: 200px; margin-right: 10px;"
                />
                <el-button :icon="Download" @click="exportConfig" :disabled="!configData.length">
                  导出
                </el-button>
              </div>
            </div>
          </template>

          <el-table
            :data="filteredConfigData"
            stripe
            border
            height="500"
            v-loading="loading"
          >
            <el-table-column type="index" width="60" label="#" />
            <el-table-column prop="key" label="配置键" min-width="300" sortable show-overflow-tooltip>
              <template #default="{ row }">
                <el-text class="config-key" @click="copyToClipboard(row.key)">
                  {{ row.key }}
                </el-text>
              </template>
            </el-table-column>
            <el-table-column prop="value" label="配置值" min-width="400" show-overflow-tooltip>
              <template #default="{ row }">
                <el-text class="config-value" @click="copyToClipboard(String(row.value))">
                  {{ formatValue(row.value) }}
                </el-text>
              </template>
            </el-table-column>
            <el-table-column label="类型" width="100">
              <template #default="{ row }">
                <el-tag :type="getTypeTagType(row.value)" size="small">
                  {{ getValueType(row.value) }}
                </el-tag>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>

      <!-- 配置信息和源 -->
      <el-col :span="8">
        <el-card class="info-card">
          <template #header>
            <span><el-icon><InfoFilled /></el-icon> 配置信息</span>
          </template>

          <el-descriptions :column="1" border size="small">
            <el-descriptions-item label="应用">
              {{ configInfo.application || '-' }}
            </el-descriptions-item>
            <el-descriptions-item label="环境">
              {{ configInfo.profile || '-' }}
            </el-descriptions-item>
            <el-descriptions-item label="分支">
              {{ configInfo.label || '-' }}
            </el-descriptions-item>
            <el-descriptions-item label="版本">
              <el-text type="info" truncated>{{ configInfo.version || '-' }}</el-text>
            </el-descriptions-item>
            <el-descriptions-item label="来源">
              <el-text type="info" truncated>{{ configInfo.source || '-' }}</el-text>
            </el-descriptions-item>
          </el-descriptions>
        </el-card>

        <!-- 搜索结果 -->
        <el-card class="search-result-card" v-if="searchResult">
          <template #header>
            <span><el-icon><Search /></el-icon> 搜索结果 ({{ Object.keys(searchResult).length }} 项)</span>
          </template>

          <el-scrollbar height="200">
            <div v-for="(value, key) in searchResult" :key="key" class="search-item">
              <div class="search-key">{{ key }}</div>
              <div class="search-value">{{ formatValue(value) }}</div>
            </div>
            <el-empty v-if="!Object.keys(searchResult).length" description="无匹配结果" />
          </el-scrollbar>
        </el-card>

        <!-- 配置键查询结果 -->
        <el-card class="key-result-card" v-if="keyResult !== null">
          <template #header>
            <span><el-icon><Key /></el-icon> 配置键查询结果</span>
          </template>

          <el-descriptions :column="1" border size="small">
            <el-descriptions-item label="键">
              {{ queryForm.configKey }}
            </el-descriptions-item>
            <el-descriptions-item label="值">
              <el-text class="key-result-value">{{ formatValue(keyResult) }}</el-text>
            </el-descriptions-item>
            <el-descriptions-item label="类型">
              <el-tag :type="getTypeTagType(keyResult)" size="small">
                {{ getValueType(keyResult) }}
              </el-tag>
            </el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  Setting, Search, Refresh, Document, Download,
  InfoFilled, Key
} from '@element-plus/icons-vue'
import { configApi } from '../api/config'

// 表单数据
const queryForm = ref({
  application: 'platform-test',
  profile: 'dev',
  label: 'main',
  keyword: '',
  configKey: ''
})

// 状态
const loading = ref(false)
const searchLoading = ref(false)
const keyLoading = ref(false)
const refreshLoading = ref(false)
const healthLoading = ref(false)

// 数据
const configData = ref([])
const configInfo = ref({})
const searchResult = ref(null)
const keyResult = ref(null)
const healthStatus = ref(null)
const filterText = ref('')

// 过滤后的配置数据
const filteredConfigData = computed(() => {
  if (!filterText.value) return configData.value
  const keyword = filterText.value.toLowerCase()
  return configData.value.filter(item =>
    item.key.toLowerCase().includes(keyword) ||
    String(item.value).toLowerCase().includes(keyword)
  )
})

// 获取配置
const fetchConfig = async () => {
  if (!queryForm.value.application || !queryForm.value.profile) {
    ElMessage.warning('请填写应用名称和环境')
    return
  }

  loading.value = true
  try {
    const res = await configApi.getConfig(
      queryForm.value.application,
      queryForm.value.profile,
      queryForm.value.label || 'main'
    )

    if (res.code === 200) {
      const properties = res.data.properties || {}
      configData.value = Object.entries(properties).map(([key, value]) => ({
        key,
        value
      }))
      configInfo.value = {
        application: res.data.application,
        profile: res.data.profile,
        label: res.data.label,
        version: res.data.version,
        source: res.data.source
      }
      ElMessage.success(`获取到 ${configData.value.length} 个配置项`)
    } else {
      ElMessage.error(res.message || '获取配置失败')
    }
  } catch (error) {
    console.error('获取配置失败:', error)
    ElMessage.error('获取配置失败: ' + (error.response?.data?.message || error.message))
  } finally {
    loading.value = false
  }
}

// 搜索配置
const searchConfigByKeyword = async () => {
  if (!queryForm.value.keyword) {
    ElMessage.warning('请输入搜索关键词')
    return
  }
  if (!queryForm.value.application || !queryForm.value.profile) {
    ElMessage.warning('请先填写应用名称和环境')
    return
  }

  searchLoading.value = true
  try {
    const res = await configApi.searchConfig(
      queryForm.value.application,
      queryForm.value.profile,
      queryForm.value.label || 'main',
      queryForm.value.keyword
    )

    if (res.code === 200) {
      searchResult.value = res.data
      ElMessage.success(`找到 ${Object.keys(res.data).length} 个匹配项`)
    } else {
      ElMessage.error(res.message || '搜索失败')
    }
  } catch (error) {
    console.error('搜索失败:', error)
    ElMessage.error('搜索失败: ' + (error.response?.data?.message || error.message))
  } finally {
    searchLoading.value = false
  }
}

// 获取指定配置键的值
const getConfigByKey = async () => {
  if (!queryForm.value.configKey) {
    ElMessage.warning('请输入配置键')
    return
  }
  if (!queryForm.value.application || !queryForm.value.profile) {
    ElMessage.warning('请先填写应用名称和环境')
    return
  }

  keyLoading.value = true
  try {
    const res = await configApi.getConfigValue(
      queryForm.value.application,
      queryForm.value.profile,
      queryForm.value.label || 'main',
      queryForm.value.configKey
    )

    if (res.code === 200) {
      keyResult.value = res.data
      ElMessage.success('获取配置值成功')
    } else {
      keyResult.value = null
      ElMessage.warning(res.message || '配置键不存在')
    }
  } catch (error) {
    console.error('获取配置值失败:', error)
    keyResult.value = null
    ElMessage.error('获取配置值失败: ' + (error.response?.data?.message || error.message))
  } finally {
    keyLoading.value = false
  }
}

// 刷新配置缓存
const refreshConfigCache = async () => {
  refreshLoading.value = true
  try {
    const res = await configApi.refreshConfig()
    if (res.code === 200) {
      ElMessage.success('配置缓存已刷新')
      // 重新加载配置
      if (queryForm.value.application && queryForm.value.profile) {
        await fetchConfig()
      }
    } else {
      ElMessage.error(res.message || '刷新缓存失败')
    }
  } catch (error) {
    console.error('刷新缓存失败:', error)
    ElMessage.error('刷新缓存失败: ' + (error.response?.data?.message || error.message))
  } finally {
    refreshLoading.value = false
  }
}

// 健康检查
const checkHealth = async () => {
  healthLoading.value = true
  try {
    const res = await configApi.health()
    if (res.code === 200) {
      healthStatus.value = res.data
      ElMessage.success('服务健康')
    } else {
      healthStatus.value = { status: 'DOWN' }
      ElMessage.error('服务异常')
    }
  } catch (error) {
    console.error('健康检查失败:', error)
    healthStatus.value = { status: 'DOWN' }
    ElMessage.error('服务连接失败')
  } finally {
    healthLoading.value = false
  }
}

// 导出配置
const exportConfig = () => {
  if (!configData.value.length) return

  const data = {}
  configData.value.forEach(item => {
    data[item.key] = item.value
  })

  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `${queryForm.value.application}-${queryForm.value.profile}-config.json`
  link.click()
  URL.revokeObjectURL(url)

  ElMessage.success('配置已导出')
}

// 复制到剪贴板
const copyToClipboard = async (text) => {
  try {
    await navigator.clipboard.writeText(text)
    ElMessage.success('已复制到剪贴板')
  } catch (error) {
    ElMessage.error('复制失败')
  }
}

// 格式化值
const formatValue = (value) => {
  if (value === null || value === undefined) return 'null'
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

// 获取值类型
const getValueType = (value) => {
  if (value === null || value === undefined) return 'null'
  if (Array.isArray(value)) return 'array'
  return typeof value
}

// 获取类型标签样式
const getTypeTagType = (value) => {
  const type = getValueType(value)
  const typeMap = {
    string: '',
    number: 'success',
    boolean: 'warning',
    object: 'info',
    array: 'info',
    null: 'danger'
  }
  return typeMap[type] || ''
}

// 初始化
checkHealth()
</script>

<style scoped>
.config-manager {
  padding: 20px;
  background: #f5f7fa;
  min-height: 100vh;
}

.header-card {
  margin-bottom: 20px;
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.title {
  font-size: 20px;
  font-weight: bold;
  display: flex;
  align-items: center;
  gap: 8px;
}

.query-card {
  margin-bottom: 20px;
}

.query-form {
  padding-top: 10px;
}

.result-row {
  margin-top: 20px;
}

.result-card {
  height: 100%;
}

.result-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.result-actions {
  display: flex;
  align-items: center;
}

.info-card {
  margin-bottom: 20px;
}

.search-result-card {
  margin-bottom: 20px;
}

.key-result-card {
  margin-bottom: 20px;
}

.config-key {
  font-family: 'Consolas', 'Monaco', monospace;
  color: #409eff;
  cursor: pointer;
}

.config-key:hover {
  text-decoration: underline;
}

.config-value {
  font-family: 'Consolas', 'Monaco', monospace;
  color: #606266;
  cursor: pointer;
}

.config-value:hover {
  color: #409eff;
}

.search-item {
  padding: 8px;
  border-bottom: 1px solid #eee;
}

.search-item:last-child {
  border-bottom: none;
}

.search-key {
  font-family: 'Consolas', 'Monaco', monospace;
  color: #409eff;
  font-size: 12px;
  margin-bottom: 4px;
}

.search-value {
  font-family: 'Consolas', 'Monaco', monospace;
  color: #606266;
  font-size: 13px;
  word-break: break-all;
}

.key-result-value {
  font-family: 'Consolas', 'Monaco', monospace;
  word-break: break-all;
}
</style>
