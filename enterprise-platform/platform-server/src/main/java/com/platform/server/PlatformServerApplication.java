package com.platform.server;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.Environment;

import java.net.InetAddress;
import java.net.UnknownHostException;

/**
 * 平台启动类
 *
 * @author platform
 */
@Slf4j
@SpringBootApplication(scanBasePackages = "com.platform")
public class PlatformServerApplication {

    public static void main(String[] args) {
        ConfigurableApplicationContext context = SpringApplication.run(PlatformServerApplication.class, args);
        printStartupInfo(context);
    }

    /**
     * 打印启动信息
     */
    private static void printStartupInfo(ConfigurableApplicationContext context) {
        Environment env = context.getEnvironment();
        String appName = env.getProperty("spring.application.name", "Platform Server");
        String port = env.getProperty("server.port", "8080");
        String contextPath = env.getProperty("server.servlet.context-path", "");
        String profile = String.join(",", env.getActiveProfiles());

        String host = "localhost";
        try {
            host = InetAddress.getLocalHost().getHostAddress();
        } catch (UnknownHostException e) {
            log.warn("无法获取主机地址，使用 localhost");
        }

        log.info("""

                ----------------------------------------------------------
                \t应用 '{}' 启动成功!
                \t环境: \t\t{}
                \t本地访问: \thttp://localhost:{}{}
                \t外部访问: \thttp://{}:{}{}
                \tAPI文档: \thttp://localhost:{}{}/doc.html
                ----------------------------------------------------------
                """,
                appName,
                profile.isEmpty() ? "default" : profile,
                port, contextPath,
                host, port, contextPath,
                port, contextPath
        );
    }
}
