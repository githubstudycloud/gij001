package com.platform.starter.web;

import com.platform.common.web.advice.GlobalExceptionHandler;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;

/**
 * Web 自动配置
 */
@Slf4j
@AutoConfiguration
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
@EnableConfigurationProperties(PlatformWebProperties.class)
public class PlatformWebAutoConfiguration {

    public PlatformWebAutoConfiguration() {
        log.info("[Platform] Web 自动配置已加载");
    }

    /**
     * 全局异常处理器
     */
    @Bean
    @ConditionalOnMissingBean
    public GlobalExceptionHandler globalExceptionHandler() {
        log.info("[Platform] 注册全局异常处理器");
        return new GlobalExceptionHandler();
    }
}
