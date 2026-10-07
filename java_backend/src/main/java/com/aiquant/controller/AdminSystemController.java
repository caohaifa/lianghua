package com.aiquant.controller;

import com.aiquant.mapper.AdminQueryMapper;
import com.aiquant.mapper.AuditLogMapper;
import com.aiquant.mapper.SystemConfigMapper;
import com.aiquant.model.ApiResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static com.aiquant.controller.AdminUserController.pageResult;

/**
 * 运营后台 · 系统(数据统计看板 + 审计日志 + 系统配置 KV)
 */
@RestController
@RequestMapping("/admin/system")
public class AdminSystemController {

    @Autowired
    private AdminQueryMapper queryMapper;
    @Autowired
    private AuditLogMapper auditLogMapper;
    @Autowired
    private SystemConfigMapper systemConfigMapper;

    /** 看板:核心指标卡 + 7日新增用户曲线 + 风险等级分布 + 成交额趋势 */
    @GetMapping("/dashboard")
    public ApiResponse<Map<String, Object>> dashboard() {
        Map<String, Object> data = new HashMap<>();
        data.put("stats", queryMapper.dashboardStats());
        LocalDateTime since = LocalDate.now().minusDays(6).atStartOfDay();
        data.put("userGrowth", queryMapper.userGrowth7d(since));
        data.put("riskDistribution", queryMapper.riskDistribution());
        data.put("tradeVolume", queryMapper.tradeVolume7d(since));
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

    // ══════════════ 系统配置 KV(t_system_config) ══════════════

    /** 配置列表(全量 KV) */
    @GetMapping("/configs")
    public ApiResponse<List<Map<String, Object>>> configs() {
        return ApiResponse.success(systemConfigMapper.selectAll());
    }

    /** 写入/更新配置(upsert) */
    @PutMapping("/configs")
    public ApiResponse<String> upsertConfig(@RequestBody Map<String, String> body) {
        String key = body.get("key");
        String value = body.get("value");
        if (key == null || key.isBlank() || key.length() > 64) {
            return ApiResponse.error(400, "key 必填且不超过 64 字符");
        }
        if (value == null || value.length() > 2000) {
            return ApiResponse.error(400, "value 必填且不超过 2000 字符");
        }
        if (systemConfigMapper.get(key) == null) {
            systemConfigMapper.insert(key, value);
        } else {
            systemConfigMapper.update(key, value);
        }
        return ApiResponse.success("配置已保存");
    }
}
