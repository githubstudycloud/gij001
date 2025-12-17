package com.platform.common.core.annotation;

import java.lang.annotation.*;

/**
 * 操作日志注解
 */
@Target({ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface Log {

    /**
     * 模块名称
     */
    String module() default "";

    /**
     * 操作类型
     */
    OperationType operationType() default OperationType.OTHER;

    /**
     * 是否保存请求参数
     */
    boolean saveRequestData() default true;

    /**
     * 是否保存响应数据
     */
    boolean saveResponseData() default false;

    /**
     * 排除的请求参数字段
     */
    String[] excludeParamNames() default {"password", "oldPassword", "newPassword"};

    /**
     * 操作类型枚举
     */
    enum OperationType {
        /**
         * 其他
         */
        OTHER,
        /**
         * 新增
         */
        INSERT,
        /**
         * 修改
         */
        UPDATE,
        /**
         * 删除
         */
        DELETE,
        /**
         * 查询
         */
        QUERY,
        /**
         * 导出
         */
        EXPORT,
        /**
         * 导入
         */
        IMPORT,
        /**
         * 登录
         */
        LOGIN,
        /**
         * 登出
         */
        LOGOUT
    }
}
