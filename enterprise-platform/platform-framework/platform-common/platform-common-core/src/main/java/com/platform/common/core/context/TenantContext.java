package com.platform.common.core.context;

import com.alibaba.ttl.TransmittableThreadLocal;

/**
 * 租户上下文
 */
public class TenantContext {

    private static final TransmittableThreadLocal<Long> TENANT_HOLDER = new TransmittableThreadLocal<>();

    /**
     * 设置当前租户 ID
     */
    public static void set(Long tenantId) {
        TENANT_HOLDER.set(tenantId);
    }

    /**
     * 获取当前租户 ID
     */
    public static Long get() {
        return TENANT_HOLDER.get();
    }

    /**
     * 清除当前租户
     */
    public static void clear() {
        TENANT_HOLDER.remove();
    }

    /**
     * 忽略租户执行
     */
    public static <T> T ignoreExecute(java.util.function.Supplier<T> supplier) {
        Long tenantId = get();
        try {
            clear();
            return supplier.get();
        } finally {
            if (tenantId != null) {
                set(tenantId);
            }
        }
    }
}
