<script setup>
import ConfigManager from './views/ConfigManager.vue'
</script>

<template>
  <el-config-provider>
    <ConfigManager />
  </el-config-provider>
</template>

<style>
#app {
  font-family: 'Helvetica Neue', Helvetica, 'PingFang SC', 'Hiragino Sans GB',
    'Microsoft YaHei', '微软雅黑', Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

body {
  margin: 0;
  padding: 0;
  background: #f5f7fa;
}
</style>
