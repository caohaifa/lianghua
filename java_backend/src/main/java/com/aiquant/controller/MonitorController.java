package com.aiquant.controller;

import com.aiquant.mapper.MonitorMapper;
import com.aiquant.model.ApiResponse;
import com.aiquant.model.Monitor;
import com.aiquant.service.MarketService;
import com.aiquant.service.SubscriptionService;
import com.aiquant.service.ai.AiDecisionGateway;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 用户自建监控:盯盘标的 + 策略组合,可暂停/恢复/删除。
 * 监控数量受套餐权益限制(免费1/基础5/专业20)。
 */
@RestController
@RequestMapping("/monitors")
public class MonitorController {

    private static final List<String> STRATEGIES =
            List.of("趋势追踪", "网格区间", "多因子轮动", "日内T+0");

    @Autowired
    private MonitorMapper monitorMapper;
    @Autowired
    private MarketService marketService;
    @Autowired
    private SubscriptionService subscriptionService;
    @Autowired
    private AiDecisionGateway aiDecisionGateway;

    /**
     * AI Agent 运行状态代理:浏览器只与 Java 通信,Python AI 保持内网(避免 CORS/暴露)。
     */
    @GetMapping("/agents-status")
    public ApiResponse<Map<String, Object>> agentsStatus() {
        return ApiResponse.success(aiDecisionGateway.agentsStatus());
    }

    @GetMapping
    public ApiResponse<List<Monitor>> list(HttpServletRequest request) {
        return ApiResponse.success(monitorMapper.selectByUser(uid(request)));
    }

    @PostMapping
    public ApiResponse<Monitor> create(@RequestBody Map<String, String> body,
                                       HttpServletRequest request) {
        String symbol = body.get("symbol");
        String strategy = body.get("strategy");
        if (symbol == null || marketService.getQuote(symbol) == null) {
            throw new RuntimeException("标的不存在或无行情");
        }
        if (strategy == null || !STRATEGIES.contains(strategy)) {
            throw new RuntimeException("策略不合法,可选: " + String.join("/", STRATEGIES));
        }
        String userId = uid(request);
        // 套餐权益:监控数量上限
        int limit = subscriptionService.getMonitorLimit(userId);
        if (monitorMapper.countByUser(userId) >= limit) {
            throw new RuntimeException("监控数量已达当前套餐上限(" + limit +
                    "个),请在「分成结算」中升级套餐");
        }
        Monitor monitor = new Monitor();
        monitor.setUserId(userId);
        monitor.setSymbol(symbol);
        monitor.setStrategy(strategy);
        monitorMapper.insert(monitor);
        return ApiResponse.success(monitorMapper.selectByIdAndUser(monitor.getId(), userId));
    }

    @PutMapping("/{id}/status")
    public ApiResponse<Monitor> updateStatus(@PathVariable Long id,
                                             @RequestBody Map<String, String> body,
                                             HttpServletRequest request) {
        String status = body.get("status");
        if (!"running".equals(status) && !"paused".equals(status)) {
            throw new RuntimeException("状态不合法(running/paused)");
        }
        if (monitorMapper.updateStatus(id, uid(request), status) == 0) {
            throw new RuntimeException("监控不存在");
        }
        return ApiResponse.success(monitorMapper.selectByIdAndUser(id, uid(request)));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, String>> delete(@PathVariable Long id,
                                                   HttpServletRequest request) {
        if (monitorMapper.deleteByIdAndUser(id, uid(request)) == 0) {
            throw new RuntimeException("监控不存在");
        }
        return ApiResponse.success(Map.of("status", "deleted"));
    }

    private String uid(HttpServletRequest request) {
        return (String) request.getAttribute("userId");
    }
}
