package com.aiquant.controller;

import com.aiquant.model.ApiResponse;
import com.aiquant.service.AuditLogService;
import com.aiquant.service.PersonalStrategyService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 运营后台 · 全局风控:一键暂停/恢复全部跟单信号分发,查看站内告警。
 */
@RestController
@RequestMapping("/admin/risk")
public class AdminRiskController {

    @Autowired
    private PersonalStrategyService personalStrategyService;
    @Autowired
    private AuditLogService auditLogService;

    /** 全局跟单风控状态 */
    @GetMapping("/copy-status")
    public ApiResponse<Map<String, Object>> copyStatus() {
        return ApiResponse.success(Map.of("paused", personalStrategyService.copyPaused()));
    }

    /** 一键暂停/恢复全部跟单 */
    @PutMapping("/copy-pause")
    public ApiResponse<Map<String, Object>> copyPause(@RequestBody Map<String, Object> body,
                                                      HttpServletRequest request) {
        boolean paused = Boolean.parseBoolean(String.valueOf(body.get("paused")));
        personalStrategyService.setCopyPaused(paused);
        auditLogService.record(String.valueOf(request.getAttribute("username")),
                "copy_pause", "global",
                Map.of("paused", paused),
                request.getRemoteAddr());
        return ApiResponse.success(Map.of("paused", paused));
    }

    /** 站内告警(全站最近) */
    @GetMapping("/alerts")
    public ApiResponse<List<com.aiquant.model.Alert>> alerts(
            @RequestParam(defaultValue = "100") int limit) {
        return ApiResponse.success(personalStrategyService.recentAlerts(Math.min(limit, 500)));
    }
}
