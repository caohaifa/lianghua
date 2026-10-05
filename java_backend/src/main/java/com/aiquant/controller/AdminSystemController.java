package com.aiquant.controller;

import com.aiquant.mapper.AdminQueryMapper;
import com.aiquant.mapper.AuditLogMapper;
import com.aiquant.model.ApiResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

import static com.aiquant.controller.AdminUserController.pageResult;

/**
 * 运营后台 · 系统(数据统计看板 + 审计日志)
 */
@RestController
@RequestMapping("/admin/system")
public class AdminSystemController {

    @Autowired
    private AdminQueryMapper queryMapper;
    @Autowired
    private AuditLogMapper auditLogMapper;

    /** 看板:核心指标卡 + 7日新增用户曲线 + 风险等级分布 */
    @GetMapping("/dashboard")
    public ApiResponse<Map<String, Object>> dashboard() {
        Map<String, Object> data = new HashMap<>();
        data.put("stats", queryMapper.dashboardStats());
        LocalDateTime since = LocalDate.now().minusDays(6).atStartOfDay();
        data.put("userGrowth", queryMapper.userGrowth7d(since));
        data.put("riskDistribution", queryMapper.riskDistribution());
        return ApiResponse.success(data);
    }

    @GetMapping("/audit-logs")
    public ApiResponse<Map<String, Object>> auditLogs(
            @RequestParam(required = false) String actorId,
            @RequestParam(required = false) String action,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        int offset = Math.max(page - 1, 0) * size;
        return ApiResponse.success(pageResult(
                auditLogMapper.list(actorId, action, offset, size),
                auditLogMapper.count(actorId, action), page, size));
    }
}
