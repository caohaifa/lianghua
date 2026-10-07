package com.aiquant.controller;

import com.aiquant.model.ApiResponse;
import com.aiquant.model.StrategyFollow;
import com.aiquant.service.PersonalStrategyService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 个人策略(用户端):人工信号台(开多/加仓/部分平仓/全部平仓/开空)、
 * 信号历史、跟单暂停/恢复、站内告警。
 */
@RestController
@RequestMapping("/personal")
public class PersonalController {

    @Autowired
    private PersonalStrategyService personalStrategyService;

    /** 下发人工信号 */
    @PostMapping("/monitors/{id}/signal")
    public ApiResponse<Map<String, Object>> signal(@PathVariable Long id,
                                                   @RequestBody Map<String, Object> body,
                                                   HttpServletRequest request) {
        String action = (String) body.get("action");
        Double amount = body.get("amount") == null ? null
                : Double.parseDouble(String.valueOf(body.get("amount")));
        Integer ratioPct = body.get("ratio_pct") == null ? null
                : Integer.parseInt(String.valueOf(body.get("ratio_pct")));
        Integer leverage = body.get("leverage") == null ? null
                : Integer.parseInt(String.valueOf(body.get("leverage")));
        return ApiResponse.success(
                personalStrategyService.signal(uid(request), id, action, amount, ratioPct, leverage));
    }

    /** 信号历史(分页) */
    @GetMapping("/monitors/{id}/signals")
    public ApiResponse<Map<String, Object>> signals(@PathVariable Long id,
                                                     @RequestParam(defaultValue = "50") int limit,
                                                     @RequestParam(defaultValue = "0") int offset,
                                                     HttpServletRequest request) {
        return ApiResponse.success(
                personalStrategyService.signals(uid(request), id,
                        Math.min(limit, 200), Math.max(offset, 0)));
    }

    /** 开空预检:检查冲突持仓 */
    @GetMapping("/monitors/{id}/precheck-short")
    public ApiResponse<Map<String, Object>> preCheckShort(@PathVariable Long id,
                                                          HttpServletRequest request) {
        return ApiResponse.success(
                personalStrategyService.preCheckShort(uid(request), id));
    }

    /** 暂停/恢复我的跟单 */
    @PutMapping("/follows/{id}/status")
    public ApiResponse<StrategyFollow> setFollowStatus(@PathVariable Long id,
                                                       @RequestBody Map<String, String> body,
                                                       HttpServletRequest request) {
        return ApiResponse.success(
                personalStrategyService.setFollowStatus(uid(request), id, body.get("status")));
    }

    /** 告警列表 + 未读数 + 全局风控状态(分页) */
    @GetMapping("/alerts")
    public ApiResponse<Map<String, Object>> alerts(
            @RequestParam(defaultValue = "50") int limit,
            @RequestParam(defaultValue = "0") int offset,
            HttpServletRequest request) {
        return ApiResponse.success(
                personalStrategyService.alerts(uid(request),
                        Math.min(limit, 200), Math.max(offset, 0)));
    }

    /** 全部标为已读 */
    @PutMapping("/alerts/read")
    public ApiResponse<Map<String, String>> readAlerts(HttpServletRequest request) {
        personalStrategyService.readAlerts(uid(request));
        return ApiResponse.success(Map.of("status", "read"));
    }

    private String uid(HttpServletRequest request) {
        return (String) request.getAttribute("userId");
    }
}
