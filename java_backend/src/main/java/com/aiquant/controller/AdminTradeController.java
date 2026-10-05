package com.aiquant.controller;

import com.aiquant.mapper.AdminQueryMapper;
import com.aiquant.model.ApiResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

import static com.aiquant.controller.AdminUserController.pageResult;

/**
 * 运营后台 · 交易管理(委托订单 + 持仓查询)
 */
@RestController
@RequestMapping("/admin/trades")
public class AdminTradeController {

    @Autowired
    private AdminQueryMapper queryMapper;

    @GetMapping("/orders")
    public ApiResponse<Map<String, Object>> orders(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        return ApiResponse.success(pageResult(
                queryMapper.listOrders(keyword, status, offset, size),
                queryMapper.countOrders(keyword, status), page, size));
    }

    @GetMapping("/positions")
    public ApiResponse<Map<String, Object>> positions(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        return ApiResponse.success(pageResult(
                queryMapper.listPositions(keyword, status, offset, size),
                queryMapper.countPositions(keyword, status), page, size));
    }
}
