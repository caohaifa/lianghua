package com.aiquant.controller;

import com.aiquant.model.ApiResponse;
import com.aiquant.model.User;
import com.aiquant.mapper.UserMapper;
import com.aiquant.service.AuditLogService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 运营后台 · 用户管理(查/封/解冻、风险等级调整)
 */
@RestController
@RequestMapping("/admin/users")
public class AdminUserController {

    @Autowired
    private UserMapper userMapper;
    @Autowired
    private AuditLogService auditLogService;

    /** 分页列表(keyword 模糊匹配手机/昵称/用户ID,可按状态与风险等级过滤) */
    @GetMapping
    public ApiResponse<Map<String, Object>> list(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Integer status,
            @RequestParam(required = false) String riskLevel,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        List<User> list = userMapper.adminList(keyword, status, riskLevel, offset, size);
        long total = userMapper.adminCount(keyword, status, riskLevel);
        return ApiResponse.success(pageResult(list, total, page, size));
    }

    /** 冻结 / 解冻用户 */
    @PutMapping("/{userId}/status")
    public ApiResponse<Void> updateStatus(@PathVariable String userId,
                                          @RequestBody Map<String, Object> body,
                                          HttpServletRequest request) {
        int status = Integer.parseInt(String.valueOf(body.get("status")));
        userMapper.updateStatus(userId, status);
        auditLogService.record(
                String.valueOf(request.getAttribute("username")),
                status == 1 ? "freeze_user" : "unfreeze_user",
                userId,
                Map.of("status", status),
                request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    /** 调整用户风险等级(R1~R5) */
    @PutMapping("/{userId}/risk-level")
    public ApiResponse<Void> updateRiskLevel(@PathVariable String userId,
                                             @RequestBody Map<String, Object> body,
                                             HttpServletRequest request) {
        String riskLevel = String.valueOf(body.get("riskLevel"));
        userMapper.adminUpdateRiskLevel(userId, riskLevel);
        auditLogService.record(
                String.valueOf(request.getAttribute("username")),
                "adjust_risk_level",
                userId,
                Map.of("riskLevel", riskLevel),
                request.getRemoteAddr());
        return ApiResponse.success(null);
    }

    static Map<String, Object> pageResult(Object list, long total, int page, int size) {
        Map<String, Object> result = new HashMap<>();
        result.put("list", list);
        result.put("total", total);
        result.put("page", page);
        result.put("size", size);
        return result;
    }
}
