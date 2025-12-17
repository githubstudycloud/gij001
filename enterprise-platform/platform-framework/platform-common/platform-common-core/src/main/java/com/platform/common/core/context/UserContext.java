package com.platform.common.core.context;

import com.alibaba.ttl.TransmittableThreadLocal;
import lombok.Data;
import lombok.experimental.Accessors;

import java.io.Serial;
import java.io.Serializable;
import java.util.Set;

/**
 * 用户上下文
 * <p>
 * 使用 TransmittableThreadLocal 支持线程池场景
 */
public class UserContext {

    private static final TransmittableThreadLocal<LoginUser> USER_HOLDER = new TransmittableThreadLocal<>();

    /**
     * 设置当前用户
     */
    public static void set(LoginUser user) {
        USER_HOLDER.set(user);
    }

    /**
     * 获取当前用户
     */
    public static LoginUser get() {
        return USER_HOLDER.get();
    }

    /**
     * 获取当前用户 ID
     */
    public static Long getUserId() {
        LoginUser user = get();
        return user != null ? user.getUserId() : null;
    }

    /**
     * 获取当前用户名
     */
    public static String getUsername() {
        LoginUser user = get();
        return user != null ? user.getUsername() : null;
    }

    /**
     * 获取当前租户 ID
     */
    public static Long getTenantId() {
        LoginUser user = get();
        return user != null ? user.getTenantId() : null;
    }

    /**
     * 获取当前部门 ID
     */
    public static Long getDeptId() {
        LoginUser user = get();
        return user != null ? user.getDeptId() : null;
    }

    /**
     * 判断是否已登录
     */
    public static boolean isLogin() {
        return get() != null;
    }

    /**
     * 清除当前用户
     */
    public static void clear() {
        USER_HOLDER.remove();
    }

    /**
     * 登录用户信息
     */
    @Data
    @Accessors(chain = true)
    public static class LoginUser implements Serializable {

        @Serial
        private static final long serialVersionUID = 1L;

        /**
         * 用户 ID
         */
        private Long userId;

        /**
         * 用户名
         */
        private String username;

        /**
         * 昵称
         */
        private String nickname;

        /**
         * 租户 ID
         */
        private Long tenantId;

        /**
         * 部门 ID
         */
        private Long deptId;

        /**
         * 数据权限范围
         */
        private Integer dataScope;

        /**
         * 部门 ID 列表 (数据权限)
         */
        private Set<Long> deptIds;

        /**
         * 角色列表
         */
        private Set<String> roles;

        /**
         * 权限列表
         */
        private Set<String> permissions;

        /**
         * 登录 IP
         */
        private String loginIp;

        /**
         * 登录时间
         */
        private Long loginTime;

        /**
         * Token
         */
        private String token;
    }
}
