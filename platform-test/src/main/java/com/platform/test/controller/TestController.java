package com.platform.test.controller;

import com.platform.common.result.Result;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * Test controller demonstrating basic functionality
 */
@Slf4j
@RestController
@RequestMapping("/api/test")
public class TestController {

    @Value("${spring.application.name:platform-test}")
    private String applicationName;

    @Value("${server.port:8080}")
    private String serverPort;

    @Value("${test.message:Hello from Platform Test!}")
    private String testMessage;

    /**
     * Health check endpoint
     */
    @GetMapping("/health")
    public Result<Map<String, Object>> health() {
        log.info("Health check called");

        Map<String, Object> data = new HashMap<>();
        data.put("status", "UP");
        data.put("application", applicationName);
        data.put("port", serverPort);
        data.put("timestamp", LocalDateTime.now());
        data.put("javaVersion", System.getProperty("java.version"));

        return Result.success(data);
    }

    /**
     * Test configuration from config server
     */
    @GetMapping("/config")
    public Result<Map<String, Object>> config() {
        log.info("Config test called");

        Map<String, Object> data = new HashMap<>();
        data.put("message", testMessage);
        data.put("source", "Spring Cloud Config Server");
        data.put("timestamp", LocalDateTime.now());

        return Result.success(data);
    }

    /**
     * Welcome endpoint
     */
    @GetMapping("/welcome")
    public Result<String> welcome() {
        String message = String.format("Welcome to %s running on port %s!",
                applicationName, serverPort);
        return Result.success(message);
    }
}
