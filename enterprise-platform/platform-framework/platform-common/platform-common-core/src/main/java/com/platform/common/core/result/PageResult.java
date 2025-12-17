package com.platform.common.core.result;

import lombok.Data;
import lombok.experimental.Accessors;

import java.io.Serial;
import java.io.Serializable;
import java.util.Collections;
import java.util.List;

/**
 * 分页结果
 *
 * @param <T> 数据类型
 */
@Data
@Accessors(chain = true)
public class PageResult<T> implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    /**
     * 数据列表
     */
    private List<T> list;

    /**
     * 总数
     */
    private long total;

    /**
     * 当前页码
     */
    private long pageNum;

    /**
     * 每页数量
     */
    private long pageSize;

    /**
     * 总页数
     */
    private long pages;

    public PageResult() {
    }

    public PageResult(List<T> list, long total) {
        this.list = list;
        this.total = total;
    }

    public PageResult(List<T> list, long total, long pageNum, long pageSize) {
        this.list = list;
        this.total = total;
        this.pageNum = pageNum;
        this.pageSize = pageSize;
        this.pages = pageSize > 0 ? (total + pageSize - 1) / pageSize : 0;
    }

    /**
     * 创建空分页结果
     */
    public static <T> PageResult<T> empty() {
        return new PageResult<>(Collections.emptyList(), 0L);
    }

    /**
     * 创建空分页结果 - 带分页参数
     */
    public static <T> PageResult<T> empty(long pageNum, long pageSize) {
        return new PageResult<>(Collections.emptyList(), 0L, pageNum, pageSize);
    }

    /**
     * 创建分页结果
     */
    public static <T> PageResult<T> of(List<T> list, long total) {
        return new PageResult<>(list, total);
    }

    /**
     * 创建分页结果 - 完整参数
     */
    public static <T> PageResult<T> of(List<T> list, long total, long pageNum, long pageSize) {
        return new PageResult<>(list, total, pageNum, pageSize);
    }

    /**
     * 判断是否有下一页
     */
    public boolean hasNext() {
        return pageNum < pages;
    }

    /**
     * 判断是否有上一页
     */
    public boolean hasPrevious() {
        return pageNum > 1;
    }

    /**
     * 判断是否为空
     */
    public boolean isEmpty() {
        return list == null || list.isEmpty();
    }
}
