package com.platform.config.controller;

import com.platform.common.result.Result;
import com.platform.config.dto.ConfigFileDTO;
import com.platform.config.dto.ConfigPropertyDTO;
import com.platform.config.service.ConfigManagementService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 配置管理控制器
 * 提供配置的 CRUD 操作接口
 */
@Slf4j
@RestController
@RequestMapping("/api/config")
@RequiredArgsConstructor
public class ConfigManagementController {

    private final ConfigManagementService configManagementService;

    /**
     * 获取配置
     * GET /api/config/{application}/{profile}
     * GET /api/config/{application}/{profile}/{label}
     *
     * @param application 应用名称
     * @param profile     环境（如：dev, test, prod）
     * @param label       分支（可选，默认为 main）
     * @return 配置属性
     */
    @GetMapping({"/{application}/{profile}", "/{application}/{profile}/{label}"})
    public Result<ConfigPropertyDTO> getConfig(
            @PathVariable String application,
            @PathVariable String profile,
            @PathVariable(required = false) String label) {

        String branch = (label != null && !label.isEmpty()) ? label : "main";
        log.info("获取配置请求: application={}, profile={}, label={}", application, profile, branch);

        try {
            ConfigPropertyDTO config = configManagementService.getConfig(application, profile, branch);
            return Result.success(config);
        } catch (Exception e) {
            log.error("获取配置失败: {}", e.getMessage(), e);
            return Result.error("获取配置失败: " + e.getMessage());
        }
    }

    /**
     * 获取配置源列表
     * GET /api/config/sources/{application}/{profile}/{label}
     *
     * @param application 应用名称
     * @param profile     环境
     * @param label       分支
     * @return 配置源列表
     */
    @GetMapping("/sources/{application}/{profile}/{label}")
    public Result<List<ConfigFileDTO>> getConfigSources(
            @PathVariable String application,
            @PathVariable String profile,
            @PathVariable String label) {

        log.info("获取配置源请求: application={}, profile={}, label={}", application, profile, label);

        try {
            List<ConfigFileDTO> sources = configManagementService.getConfigSources(application, profile, label);
            return Result.success(sources);
        } catch (Exception e) {
            log.error("获取配置源失败: {}", e.getMessage(), e);
            return Result.error("获取配置源失败: " + e.getMessage());
        }
    }

    /**
     * 获取指定配置键的值
     * GET /api/config/value/{application}/{profile}/{label}?key=xxx
     *
     * @param application 应用名称
     * @param profile     环境
     * @param label       分支
     * @param key         配置键
     * @return 配置值
     */
    @GetMapping("/value/{application}/{profile}/{label}")
    public Result<Object> getConfigValue(
            @PathVariable String application,
            @PathVariable String profile,
            @PathVariable String label,
            @RequestParam String key) {

        log.info("获取配置值请求: application={}, profile={}, label={}, key={}",
                application, profile, label, key);

        try {
            Object value = configManagementService.getConfigValue(application, profile, label, key);
            if (value != null) {
                return Result.success(value);
            } else {
                return Result.error(404, "配置键不存在: " + key);
            }
        } catch (Exception e) {
            log.error("获取配置值失败: {}", e.getMessage(), e);
            return Result.error("获取配置值失败: " + e.getMessage());
        }
    }

    /**
     * 搜索配置
     * GET /api/config/search/{application}/{profile}/{label}?keyword=xxx
     *
     * @param application 应用名称
     * @param profile     环境
     * @param label       分支
     * @param keyword     搜索关键词
     * @return 匹配的配置属性
     */
    @GetMapping("/search/{application}/{profile}/{label}")
    public Result<Map<String, Object>> searchConfig(
            @PathVariable String application,
            @PathVariable String profile,
            @PathVariable String label,
            @RequestParam String keyword) {

        log.info("搜索配置请求: application={}, profile={}, label={}, keyword={}",
                application, profile, label, keyword);

        try {
            Map<String, Object> result = configManagementService.searchConfig(
                    application, profile, label, keyword);
            return Result.success(result);
        } catch (Exception e) {
            log.error("搜索配置失败: {}", e.getMessage(), e);
            return Result.error("搜索配置失败: " + e.getMessage());
        }
    }

    /**
     * 刷新配置缓存
     * POST /api/config/refresh
     *
     * @return 操作结果
     */
    @PostMapping("/refresh")
    public Result<String> refreshConfig() {
        log.info("刷新配置缓存请求");

        try {
            configManagementService.refreshConfig();
            return Result.success("配置缓存已刷新");
        } catch (Exception e) {
            log.error("刷新配置缓存失败: {}", e.getMessage(), e);
            return Result.error("刷新配置缓存失败: " + e.getMessage());
        }
    }

    /**
     * 健康检查
     * GET /api/config/health
     *
     * @return 健康状态
     */
    @GetMapping("/health")
    public Result<Map<String, Object>> health() {
        return Result.success(Map.of(
                "status", "UP",
                "service", "config-management",
                "timestamp", System.currentTimeMillis()
        ));
    }
}
