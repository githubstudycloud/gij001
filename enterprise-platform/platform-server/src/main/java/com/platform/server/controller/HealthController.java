package com.platform.server.controller;

import com.platform.common.core.result.R;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 健康检查接口
 *
 * @author platform
 */
@Tag(name = "健康检查")
@RestController
@RequestMapping("/health")
public class HealthController {

    @Operation(summary = "健康检查")
    @GetMapping
    public R<Map<String, Object>> health() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("status", "UP");
        data.put("time", LocalDateTime.now());
        data.put("version", "1.0.0-SNAPSHOT");
        return R.ok(data);
    }

    @Operation(summary = "服务信息")
    @GetMapping("/info")
    public R<Map<String, Object>> info() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("name", "Enterprise Platform");
        data.put("description", "企业级项目底座");
        data.put("javaVersion", System.getProperty("java.version"));
        data.put("osName", System.getProperty("os.name"));
        data.put("osArch", System.getProperty("os.arch"));
        return R.ok(data);
    }
}
