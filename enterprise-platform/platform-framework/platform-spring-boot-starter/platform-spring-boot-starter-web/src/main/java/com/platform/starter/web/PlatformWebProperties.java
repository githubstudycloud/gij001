package com.platform.starter.web;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Web 配置属性
 */
@Data
@ConfigurationProperties(prefix = "platform.web")
public class PlatformWebProperties {

    /**
     * 是否启用
     */
    private boolean enabled = true;

    /**
     * 跨域配置
     */
    private CorsConfig cors = new CorsConfig();

    /**
     * XSS 配置
     */
    private XssConfig xss = new XssConfig();

    /**
     * 跨域配置
     */
    @Data
    public static class CorsConfig {
        /**
         * 是否启用跨域
         */
        private boolean enabled = true;

        /**
         * 允许的来源
         */
        private String allowedOrigins = "*";

        /**
         * 允许的方法
         */
        private String allowedMethods = "*";

        /**
         * 允许的头部
         */
        private String allowedHeaders = "*";

        /**
         * 暴露的头部
         */
        private String exposedHeaders = "";

        /**
         * 预检请求缓存时间 (秒)
         */
        private long maxAge = 3600;
    }

    /**
     * XSS 配置
     */
    @Data
    public static class XssConfig {
        /**
         * 是否启用 XSS 过滤
         */
        private boolean enabled = true;

        /**
         * 排除的 URL
         */
        private String[] excludeUrls = {};
    }
}
