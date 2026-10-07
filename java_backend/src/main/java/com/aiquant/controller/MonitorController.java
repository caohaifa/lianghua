package com.aiquant.controller;

import com.aiquant.mapper.MonitorMapper;
import com.aiquant.mapper.StrategyFollowMapper;
import com.aiquant.mapper.StrategyPublishMapper;
import com.aiquant.model.ApiResponse;
import com.aiquant.model.Monitor;
import com.aiquant.model.StrategyPublish;
import com.aiquant.service.MarketService;
import com.aiquant.service.ai.AiDecisionGateway;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 用户自建监控:盯盘标的 + 策略组合,可暂停/恢复/删除。
 */
@RestController
@RequestMapping("/monitors")
public class MonitorController {

    private static final List<String> STRATEGIES =
            List.of("趋势追踪", "网格区间", "多因子轮动", "日内T+0", "个人策略");

    @Autowired
    private MonitorMapper monitorMapper;
    @Autowired
    private StrategyPublishMapper publishMapper;
    @Autowired
    private StrategyFollowMapper strategyFollowMapper;
    @Autowired
    private MarketService marketService;
    @Autowired
    private AiDecisionGateway aiDecisionGateway;

    private final ObjectMapper objectMapper = new ObjectMapper();

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

    /** 监控详情(信号台拉取策略参数用) */
    @GetMapping("/{id}")
    public ApiResponse<Monitor> detail(@PathVariable Long id, HttpServletRequest request) {
        Monitor monitor = monitorMapper.selectByIdAndUser(id, uid(request));
        if (monitor == null) {
            throw new RuntimeException("监控不存在");
        }
        return ApiResponse.success(monitor);
    }

    /**
     * 个人策略参数保存(全人工定义):body {"params": {键: 值, ...}},
     * 仅个人策略监控可设置,最多 20 项。
     */
    @PutMapping("/{id}/params")
    public ApiResponse<Monitor> updateParams(@PathVariable Long id,
                                             @RequestBody Map<String, Object> body,
                                             HttpServletRequest request) {
        String userId = uid(request);
        Monitor monitor = monitorMapper.selectByIdAndUser(id, userId);
        if (monitor == null) {
            throw new RuntimeException("监控不存在");
        }
        if (!"个人策略".equals(monitor.getStrategy())) {
            throw new RuntimeException("仅个人策略支持自定义参数");
        }
        Object paramsObj = body.get("params");
        if (!(paramsObj instanceof Map)) {
            throw new RuntimeException("参数格式不正确,需为键值对对象");
        }
        Map<?, ?> params = (Map<?, ?>) paramsObj;
        if (params.size() > 20) {
            throw new RuntimeException("参数最多 20 项");
        }
        for (Map.Entry<?, ?> e : params.entrySet()) {
            String key = String.valueOf(e.getKey()).trim();
            String value = String.valueOf(e.getValue()).trim();
            if (key.isEmpty() || key.length() > 30) {
                throw new RuntimeException("参数名需为 1-30 个字符: " + key);
            }
            if (value.length() > 200) {
                throw new RuntimeException("参数值最长 200 字符: " + key);
            }
        }
        String json;
        try {
            json = objectMapper.writeValueAsString(params);
        } catch (Exception ex) {
            throw new RuntimeException("参数序列化失败");
        }
        monitorMapper.updateParams(id, userId, json);
        return ApiResponse.success(monitorMapper.selectByIdAndUser(id, userId));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, String>> delete(@PathVariable Long id,
                                                   HttpServletRequest request) {
        String userId = uid(request);
        if (monitorMapper.deleteByIdAndUser(id, userId) == 0) {
            throw new RuntimeException("监控不存在");
        }
        // 级联:删除已发布的监控时同步下架并停止相关跟单
        StrategyPublish publish = publishMapper.selectByLeaderAndMonitor(userId, id);
        if (publish != null) {
            publishMapper.updateStatus(publish.getId(), "offline");
            strategyFollowMapper.stopByPublishId(publish.getId());
        }
        return ApiResponse.success(Map.of("status", "deleted"));
    }

    private String uid(HttpServletRequest request) {
        return (String) request.getAttribute("userId");
    }
}
