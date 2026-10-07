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
 * 运营后台 · 计费管理(钱包流水)
 */
@RestController
@RequestMapping("/admin/billing")
public class AdminBillingController {

    @Autowired
    private AdminQueryMapper queryMapper;

    @GetMapping("/wallet")
    public ApiResponse<Map<String, Object>> wallet(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String type,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        return ApiResponse.success(pageResult(
                queryMapper.listWalletTransactions(keyword, type, offset, size),
                queryMapper.countWalletTransactions(keyword, type), page, size));
    }
}
