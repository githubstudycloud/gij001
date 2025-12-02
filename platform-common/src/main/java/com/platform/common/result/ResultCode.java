package com.platform.common.result;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * Result code enumeration
 */
@Getter
@AllArgsConstructor
public enum ResultCode {

    // Success
    SUCCESS(200, "Success"),

    // Client errors (4xx)
    BAD_REQUEST(400, "Bad Request"),
    UNAUTHORIZED(401, "Unauthorized"),
    FORBIDDEN(403, "Forbidden"),
    NOT_FOUND(404, "Not Found"),
    METHOD_NOT_ALLOWED(405, "Method Not Allowed"),
    CONFLICT(409, "Conflict"),
    UNPROCESSABLE_ENTITY(422, "Unprocessable Entity"),
    TOO_MANY_REQUESTS(429, "Too Many Requests"),

    // Server errors (5xx)
    INTERNAL_SERVER_ERROR(500, "Internal Server Error"),
    NOT_IMPLEMENTED(501, "Not Implemented"),
    BAD_GATEWAY(502, "Bad Gateway"),
    SERVICE_UNAVAILABLE(503, "Service Unavailable"),
    GATEWAY_TIMEOUT(504, "Gateway Timeout"),

    // Business errors (1xxx)
    BUSINESS_ERROR(1000, "Business Error"),
    VALIDATION_ERROR(1001, "Validation Error"),
    DUPLICATE_KEY_ERROR(1002, "Duplicate Key Error"),

    // Custom errors
    CONFIG_ERROR(2000, "Configuration Error"),
    DATABASE_ERROR(2001, "Database Error"),
    CACHE_ERROR(2002, "Cache Error"),
    NETWORK_ERROR(2003, "Network Error");

    private final Integer code;
    private final String message;
}
