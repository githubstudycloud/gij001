package com.platform.config.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.util.Map;

/**
 * 配置属性数据传输对象
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConfigPropertyDTO implements Serializable {

    private static final long serialVersionUID = 1L;

    /**
     * 应用名称
     */
    private String application;

    /**
     * 环境（如：dev, test, prod）
     */
    private String profile;

    /**
     * 分支名称
     */
    private String label;

    /**
     * 配置属性键值对
     */
    private Map<String, Object> properties;

    /**
     * 配置来源
     */
    private String source;

    /**
     * 版本号
     */
    private String version;
}
