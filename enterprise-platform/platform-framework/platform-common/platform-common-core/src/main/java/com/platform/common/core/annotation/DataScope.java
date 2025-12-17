package com.platform.common.core.annotation;

import java.lang.annotation.*;

/**
 * 数据权限注解
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface DataScope {

    /**
     * 部门表的别名
     */
    String deptAlias() default "";

    /**
     * 用户表的别名
     */
    String userAlias() default "";

    /**
     * 部门 ID 字段名
     */
    String deptIdColumn() default "dept_id";

    /**
     * 用户 ID 字段名
     */
    String userIdColumn() default "create_by";
}
