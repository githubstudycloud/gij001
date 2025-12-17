package com.platform.common.core.exception;

import com.platform.common.core.result.IResultCode;
import com.platform.common.core.result.ResultCode;
import lombok.Getter;

import java.io.Serial;

/**
 * 基础异常
 */
@Getter
public class BaseException extends RuntimeException {

    @Serial
    private static final long serialVersionUID = 1L;

    /**
     * 错误码
     */
    private final int code;

    /**
     * 错误消息
     */
    private final String message;

    public BaseException(String message) {
        super(message);
        this.code = ResultCode.FAILURE.getCode();
        this.message = message;
    }

    public BaseException(int code, String message) {
        super(message);
        this.code = code;
        this.message = message;
    }

    public BaseException(IResultCode resultCode) {
        super(resultCode.getMsg());
        this.code = resultCode.getCode();
        this.message = resultCode.getMsg();
    }

    public BaseException(IResultCode resultCode, String message) {
        super(message);
        this.code = resultCode.getCode();
        this.message = message;
    }

    public BaseException(String message, Throwable cause) {
        super(message, cause);
        this.code = ResultCode.FAILURE.getCode();
        this.message = message;
    }

    public BaseException(int code, String message, Throwable cause) {
        super(message, cause);
        this.code = code;
        this.message = message;
    }
}
