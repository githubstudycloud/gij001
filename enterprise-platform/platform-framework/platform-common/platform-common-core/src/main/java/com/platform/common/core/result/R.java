package com.platform.common.core.result;

import lombok.Data;
import lombok.experimental.Accessors;

import java.io.Serial;
import java.io.Serializable;

/**
 * 统一响应结果
 *
 * @param <T> 数据类型
 */
@Data
@Accessors(chain = true)
public class R<T> implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    /**
     * 状态码
     */
    private int code;

    /**
     * 消息
     */
    private String msg;

    /**
     * 数据
     */
    private T data;

    /**
     * 时间戳
     */
    private long timestamp;

    /**
     * 链路追踪 ID
     */
    private String traceId;

    public R() {
        this.timestamp = System.currentTimeMillis();
    }

    public R(int code, String msg) {
        this();
        this.code = code;
        this.msg = msg;
    }

    public R(int code, String msg, T data) {
        this(code, msg);
        this.data = data;
    }

    /**
     * 成功
     */
    public static <T> R<T> ok() {
        return new R<>(ResultCode.SUCCESS.getCode(), ResultCode.SUCCESS.getMsg());
    }

    /**
     * 成功 - 带数据
     */
    public static <T> R<T> ok(T data) {
        return new R<>(ResultCode.SUCCESS.getCode(), ResultCode.SUCCESS.getMsg(), data);
    }

    /**
     * 成功 - 自定义消息
     */
    public static <T> R<T> ok(String msg, T data) {
        return new R<>(ResultCode.SUCCESS.getCode(), msg, data);
    }

    /**
     * 失败
     */
    public static <T> R<T> fail() {
        return new R<>(ResultCode.FAILURE.getCode(), ResultCode.FAILURE.getMsg());
    }

    /**
     * 失败 - 自定义消息
     */
    public static <T> R<T> fail(String msg) {
        return new R<>(ResultCode.FAILURE.getCode(), msg);
    }

    /**
     * 失败 - 自定义状态码和消息
     */
    public static <T> R<T> fail(int code, String msg) {
        return new R<>(code, msg);
    }

    /**
     * 失败 - 使用 ResultCode
     */
    public static <T> R<T> fail(IResultCode resultCode) {
        return new R<>(resultCode.getCode(), resultCode.getMsg());
    }

    /**
     * 失败 - 使用 ResultCode 并覆盖消息
     */
    public static <T> R<T> fail(IResultCode resultCode, String msg) {
        return new R<>(resultCode.getCode(), msg);
    }

    /**
     * 判断是否成功
     */
    public boolean isSuccess() {
        return ResultCode.SUCCESS.getCode() == this.code;
    }

    /**
     * 设置链路追踪 ID
     */
    public R<T> traceId(String traceId) {
        this.traceId = traceId;
        return this;
    }
}
