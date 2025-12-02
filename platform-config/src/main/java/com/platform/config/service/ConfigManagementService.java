package com.platform.config.service;

import com.platform.config.dto.ConfigFileDTO;
import com.platform.config.dto.ConfigPropertyDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.config.environment.Environment;
import org.springframework.cloud.config.environment.PropertySource;
import org.springframework.cloud.config.server.environment.EnvironmentRepository;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 配置管理服务
 * 提供配置的查询功能，通过 Spring Cloud Config Server 读取 GitLab 中的配置
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ConfigManagementService {

    private final EnvironmentRepository environmentRepository;

    /**
     * 获取指定应用和环境的配置
     *
     * @param application 应用名称
     * @param profile     环境
     * @param label       分支
     * @return 配置属性
     */
    public ConfigPropertyDTO getConfig(String application, String profile, String label) {
        log.info("获取配置: application={}, profile={}, label={}", application, profile, label);

        try {
            Environment environment = environmentRepository.findOne(application, profile, label);

            Map<String, Object> properties = new LinkedHashMap<>();
            String source = null;
            String version = environment.getVersion();

            // 合并所有属性源
            for (PropertySource propertySource : environment.getPropertySources()) {
                if (source == null) {
                    source = propertySource.getName();
                }
                @SuppressWarnings("unchecked")
                Map<String, Object> sourceProperties = (Map<String, Object>) propertySource.getSource();
                properties.putAll(sourceProperties);
            }

            return ConfigPropertyDTO.builder()
                    .application(application)
                    .profile(profile)
                    .label(label)
                    .properties(properties)
                    .source(source)
                    .version(version)
                    .build();

        } catch (Exception e) {
            log.error("获取配置失败: {}", e.getMessage(), e);
            throw new RuntimeException("获取配置失败: " + e.getMessage(), e);
        }
    }

    /**
     * 获取配置属性源列表
     *
     * @param application 应用名称
     * @param profile     环境
     * @param label       分支
     * @return 属性源列表
     */
    public List<ConfigFileDTO> getConfigSources(String application, String profile, String label) {
        log.info("获取配置源: application={}, profile={}, label={}", application, profile, label);

        try {
            Environment environment = environmentRepository.findOne(application, profile, label);

            List<ConfigFileDTO> sources = new ArrayList<>();
            for (PropertySource propertySource : environment.getPropertySources()) {
                ConfigFileDTO dto = ConfigFileDTO.builder()
                        .application(application)
                        .profile(profile)
                        .label(label)
                        .fileName(propertySource.getName())
                        .path(propertySource.getName())
                        .build();
                sources.add(dto);
            }

            return sources;

        } catch (Exception e) {
            log.error("获取配置源失败: {}", e.getMessage(), e);
            throw new RuntimeException("获取配置源失败: " + e.getMessage(), e);
        }
    }

    /**
     * 获取指定配置键的值
     *
     * @param application 应用名称
     * @param profile     环境
     * @param label       分支
     * @param key         配置键
     * @return 配置值
     */
    public Object getConfigValue(String application, String profile, String label, String key) {
        log.info("获取配置值: application={}, profile={}, label={}, key={}",
                application, profile, label, key);

        ConfigPropertyDTO config = getConfig(application, profile, label);
        return config.getProperties().get(key);
    }

    /**
     * 搜索配置
     *
     * @param application 应用名称
     * @param profile     环境
     * @param label       分支
     * @param keyword     搜索关键词
     * @return 匹配的配置属性
     */
    public Map<String, Object> searchConfig(String application, String profile, String label, String keyword) {
        log.info("搜索配置: application={}, profile={}, label={}, keyword={}",
                application, profile, label, keyword);

        ConfigPropertyDTO config = getConfig(application, profile, label);
        Map<String, Object> result = new LinkedHashMap<>();

        String lowerKeyword = keyword.toLowerCase();
        for (Map.Entry<String, Object> entry : config.getProperties().entrySet()) {
            if (entry.getKey().toLowerCase().contains(lowerKeyword) ||
                (entry.getValue() != null && entry.getValue().toString().toLowerCase().contains(lowerKeyword))) {
                result.put(entry.getKey(), entry.getValue());
            }
        }

        return result;
    }

    /**
     * 刷新配置缓存
     * 注意：Spring Cloud Config Server 默认会缓存配置，此方法用于清除缓存
     */
    public void refreshConfig() {
        log.info("刷新配置缓存");
        // Spring Cloud Config Server 的缓存刷新通过 /actuator/refresh 端点实现
        // 这里可以添加额外的缓存清理逻辑
    }
}
