package com.platform.common.core.exception;

import com.platform.common.core.result.IResultCode;
import com.platform.common.core.result.ResultCode;

import java.io.Serial;

/**
 * 业务异常
 */
public class BizException extends BaseException {

    @Serial
    private static final long serialVersionUID = 1L;

    public BizException(String message) {
        super(ResultCode.BIZ_ERROR.getCode(), message);
    }

    public BizException(int code, String message) {
        super(code, message);
    }

    public BizException(IResultCode resultCode) {
        super(resultCode);
    }

    public BizException(IResultCode resultCode, String message) {
        super(resultCode, message);
    }

    /**
     * 快速创建业务异常
     */
    public static BizException of(String message) {
        return new BizException(message);
    }

    /**
     * 快速创建业务异常 - 带错误码
     */
    public static BizException of(int code, String message) {
        return new BizException(code, message);
    }

    /**
     * 快速创建业务异常 - 使用 ResultCode
     */
    public static BizException of(IResultCode resultCode) {
        return new BizException(resultCode);
    }
}
