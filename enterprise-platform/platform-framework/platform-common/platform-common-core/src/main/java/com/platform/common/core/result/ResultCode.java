package com.platform.common.core.result;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 通用结果码枚举
 */
@Getter
@AllArgsConstructor
public enum ResultCode implements IResultCode {

    // ==================== 成功 ====================
    SUCCESS(200, "操作成功"),

    // ==================== 客户端错误 4xx ====================
    FAILURE(400, "操作失败"),
    BAD_REQUEST(400, "请求参数错误"),
    UNAUTHORIZED(401, "未授权，请先登录"),
    FORBIDDEN(403, "无权访问"),
    NOT_FOUND(404, "资源不存在"),
    METHOD_NOT_ALLOWED(405, "请求方法不允许"),
    REQUEST_TIMEOUT(408, "请求超时"),
    CONFLICT(409, "资源冲突"),
    TOO_MANY_REQUESTS(429, "请求过于频繁，请稍后再试"),

    // ==================== 服务端错误 5xx ====================
    INTERNAL_SERVER_ERROR(500, "服务器内部错误"),
    SERVICE_UNAVAILABLE(503, "服务不可用"),

    // ==================== 业务错误 1xxx ====================
    // 参数验证 10xx
    PARAM_ERROR(1001, "参数错误"),
    PARAM_MISS(1002, "缺少必要参数"),
    PARAM_TYPE_ERROR(1003, "参数类型错误"),
    PARAM_VALID_ERROR(1004, "参数校验失败"),

    // 用户认证 11xx
    USER_NOT_LOGIN(1101, "用户未登录"),
    USER_LOGIN_EXPIRED(1102, "登录已过期"),
    USER_ACCOUNT_DISABLED(1103, "账号已被禁用"),
    USER_ACCOUNT_LOCKED(1104, "账号已被锁定"),
    USER_ACCOUNT_NOT_EXIST(1105, "账号不存在"),
    USER_PASSWORD_ERROR(1106, "密码错误"),
    USER_CAPTCHA_ERROR(1107, "验证码错误"),
    USER_TOKEN_INVALID(1108, "Token 无效"),

    // 权限 12xx
    PERMISSION_DENIED(1201, "没有操作权限"),
    ROLE_NOT_EXIST(1202, "角色不存在"),
    DATA_SCOPE_DENIED(1203, "没有数据权限"),

    // 数据操作 13xx
    DATA_NOT_EXIST(1301, "数据不存在"),
    DATA_ALREADY_EXIST(1302, "数据已存在"),
    DATA_SAVE_ERROR(1303, "数据保存失败"),
    DATA_UPDATE_ERROR(1304, "数据更新失败"),
    DATA_DELETE_ERROR(1305, "数据删除失败"),

    // 文件操作 14xx
    FILE_NOT_FOUND(1401, "文件不存在"),
    FILE_UPLOAD_ERROR(1402, "文件上传失败"),
    FILE_DOWNLOAD_ERROR(1403, "文件下载失败"),
    FILE_TYPE_NOT_ALLOWED(1404, "文件类型不允许"),
    FILE_SIZE_EXCEEDED(1405, "文件大小超出限制"),

    // 外部服务 15xx
    REMOTE_SERVICE_ERROR(1501, "远程服务调用失败"),
    THIRD_PARTY_ERROR(1502, "第三方接口调用失败"),

    // 业务逻辑 16xx
    BIZ_ERROR(1601, "业务逻辑错误"),
    REPEAT_SUBMIT(1602, "请勿重复提交"),
    RATE_LIMIT_EXCEEDED(1603, "访问频率超限");

    /**
     * 状态码
     */
    private final int code;

    /**
     * 消息
     */
    private final String msg;
}
