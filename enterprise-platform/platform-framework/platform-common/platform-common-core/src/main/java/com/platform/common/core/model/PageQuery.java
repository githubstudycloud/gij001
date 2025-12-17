package com.platform.common.core.model;

import lombok.Data;

import java.io.Serial;
import java.io.Serializable;

/**
 * 分页查询基类
 */
@Data
public class PageQuery implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    /**
     * 默认页码
     */
    private static final int DEFAULT_PAGE_NUM = 1;

    /**
     * 默认每页数量
     */
    private static final int DEFAULT_PAGE_SIZE = 10;

    /**
     * 最大每页数量
     */
    private static final int MAX_PAGE_SIZE = 500;

    /**
     * 当前页码
     */
    private Integer pageNum;

    /**
     * 每页数量
     */
    private Integer pageSize;

    /**
     * 排序字段
     */
    private String orderBy;

    /**
     * 排序方式 (asc/desc)
     */
    private String orderType;

    /**
     * 获取页码 (安全获取)
     */
    public Integer getPageNum() {
        return pageNum == null || pageNum < 1 ? DEFAULT_PAGE_NUM : pageNum;
    }

    /**
     * 获取每页数量 (安全获取)
     */
    public Integer getPageSize() {
        if (pageSize == null || pageSize < 1) {
            return DEFAULT_PAGE_SIZE;
        }
        return Math.min(pageSize, MAX_PAGE_SIZE);
    }

    /**
     * 获取偏移量
     */
    public Integer getOffset() {
        return (getPageNum() - 1) * getPageSize();
    }

    /**
     * 是否升序
     */
    public boolean isAsc() {
        return "asc".equalsIgnoreCase(orderType);
    }
}
