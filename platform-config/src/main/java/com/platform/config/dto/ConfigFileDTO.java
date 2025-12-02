package com.platform.config.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;

/**
 * 配置文件数据传输对象
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConfigFileDTO implements Serializable {

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
     * 文件名
     */
    private String fileName;

    /**
     * 配置内容
     */
    private String content;

    /**
     * 文件路径
     */
    private String path;

    /**
     * 提交信息
     */
    private String commitMessage;
}
