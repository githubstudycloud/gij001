package com.platform.common.core.annotation;

import java.lang.annotation.*;
import java.util.concurrent.TimeUnit;

/**
 * 防重复提交注解
 */
@Target({ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface RepeatSubmit {

    /**
     * 间隔时间 (毫秒)
     */
    int interval() default 5000;

    /**
     * 时间单位
     */
    TimeUnit timeUnit() default TimeUnit.MILLISECONDS;

    /**
     * 提示消息
     */
    String message() default "请勿重复提交";

    /**
     * 锁类型
     */
    LockType lockType() default LockType.GLOBAL;

    /**
     * 锁类型枚举
     */
    enum LockType {
        /**
         * 用户级别锁 (同一用户不能重复提交)
         */
        USER,
        /**
         * 全局锁 (任何人都不能重复提交同一请求)
         */
        GLOBAL,
        /**
         * 参数级别锁 (根据参数判断)
         */
        PARAM
    }
}
