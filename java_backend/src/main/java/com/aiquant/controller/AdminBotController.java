package com.aiquant.controller;

import com.aiquant.mapper.MonitorMapper;
import com.aiquant.mapper.OrderMapper;
import com.aiquant.mapper.PositionMapper;
import com.aiquant.mapper.QuantBotMapper;
import com.aiquant.mapper.SignalLogMapper;
import com.aiquant.model.ApiResponse;
import com.aiquant.model.Monitor;
import com.aiquant.model.Position;
import com.aiquant.model.QuantBot;
import com.aiquant.service.AuditLogService;
import com.aiquant.service.ai.BotParamSchema;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 后台-机器人管理:机器人列表(关联监控运行状态)、启停、参数调整。
 * 启停与改参均为敏感资金动作,统一写审计日志。
 */
@RestController
@RequestMapping("/admin/bots")
public class AdminBotController {

    @Autowired private QuantBotMapper quantBotMapper;
    @Autowired private MonitorMapper monitorMapper;
    @Autowired private AuditLogService auditLogService;
    @Autowired private ObjectMapper objectMapper;
    @Autowired private PositionMapper positionMapper;
    @Autowired private OrderMapper orderMapper;
    @Autowired private SignalLogMapper signalLogMapper;

    /** 机器人列表(带监控状态) */
    @GetMapping
    public ApiResponse<Map<String, Object>> list() {
        List<QuantBot> bots = quantBotMapper.selectAll();
        List<Map<String, Object>> out = new ArrayList<>();
        for (QuantBot b : bots) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", b.getId());
            m.put("botUserId", b.getBotUserId());
            m.put("monitorId", b.getMonitorId());
            m.put("strategyKey", b.getStrategyKey());
            m.put("symbol", b.getSymbol());
            m.put("configJson", b.getConfigJson());
            m.put("createdAt", b.getCreatedAt());
            Monitor mon = b.getMonitorId() == null ? null : monitorMapper.selectByIdAny(b.getMonitorId());
            m.put("monitorStatus", mon == null ? null : mon.getStatus());
            m.put("monitorSignal", mon == null ? null : mon.getSignal());
            m.put("strategy", mon == null ? null : mon.getStrategy());
            out.add(m);
        }
        return ApiResponse.success(Map.of("list", out, "total", out.size()));
    }

    /** 各策略可调参数模式(键/标签/单位/范围/默认值),前端据此渲染结构化表单。 */
    @GetMapping("/param-schema")
    public ApiResponse<Map<String, List<BotParamSchema.ParamDef>>> paramSchema() {
        return ApiResponse.success(BotParamSchema.all());
    }

    /** 启停机器人(切换其监控 status) */
    @PutMapping("/{id}/status")
    public ApiResponse<String> status(@PathVariable Long id, @RequestBody Map<String, String> body,
                                      HttpServletRequest request) {
        QuantBot bot = quantBotMapper.selectById(id);
        if (bot == null) return ApiResponse.error(400, "机器人不存在");
        if (bot.getMonitorId() == null) return ApiResponse.error(400, "该机器人未绑定监控,无法启停");
        String status = body.get("status");
        if (!"running".equals(status) && !"paused".equals(status)) {
            return ApiResponse.error(400, "status 仅支持 running/paused");
        }
        monitorMapper.updateStatusAny(bot.getMonitorId(), status);
        auditLogService.record(actor(request), "admin_bot_status", String.valueOf(id),
                Map.of("monitorId", bot.getMonitorId(), "status", status), request.getRemoteAddr());
        return ApiResponse.success("机器人已" + ("running".equals(status) ? "启动" : "暂停"));
    }

    /** 调整机器人配置(config_json) */
    @PutMapping("/{id}/config")
    public ApiResponse<String> config(@PathVariable Long id, @RequestBody Map<String, String> body,
                                      HttpServletRequest request) {
        QuantBot bot = quantBotMapper.selectById(id);
        if (bot == null) return ApiResponse.error(400, "机器人不存在");
        String configJson = body.get("config_json");
        if (configJson == null || configJson.length() > 2000) {
            return ApiResponse.error(400, "config_json 必填且不超过 2000 字符");
        }
        // 必须是合法 JSON 对象:坏配置会在下一轮扫描被解析,直接让执行链路抛错
        JsonNode node;
        try {
            node = objectMapper.readTree(configJson);
            if (!node.isObject()) {
                return ApiResponse.error(400, "config_json 必须是 JSON 对象 {...}");
            }
        } catch (Exception e) {
            return ApiResponse.error(400, "config_json 不是合法 JSON");
        }
        // 按策略参数模式校验:未知键拒绝、数值范围/整数校验(缺失键回退默认值)
        String schemaErr = BotParamSchema.validate(bot.getStrategyKey(), node);
        if (schemaErr != null) {
            return ApiResponse.error(400, schemaErr);
        }
        quantBotMapper.updateConfig(id, configJson);
        auditLogService.record(actor(request), "admin_bot_config", String.valueOf(id),
                Map.of("strategyKey", bot.getStrategyKey() == null ? "" : bot.getStrategyKey()),
                request.getRemoteAddr());
        return ApiResponse.success("配置已更新");
    }

    /** 机器人绩效透视:持仓 / 盈亏 / 订单统计 / 最新信号 */
    @GetMapping("/{id}/stats")
    public ApiResponse<Map<String, Object>> stats(@PathVariable Long id) {
        QuantBot bot = quantBotMapper.selectById(id);
        if (bot == null) return ApiResponse.error(400, "机器人不存在");
        String uid = bot.getBotUserId();

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("botId", bot.getId());
        out.put("botUserId", uid);
        out.put("strategyKey", bot.getStrategyKey());
        out.put("symbol", bot.getSymbol());
        out.put("configJson", bot.getConfigJson());

        // 监控状态与最新信号(注:仅最新一条,系统未存信号历史)
        Monitor mon = bot.getMonitorId() == null ? null : monitorMapper.selectByIdAny(bot.getMonitorId());
        out.put("monitorStatus", mon == null ? null : mon.getStatus());
        out.put("latestSignal", mon == null ? null : mon.getSignal());

        // 持仓 + 未实现盈亏(取自持仓 pnl,由价格同步任务实时维护)
        List<Position> open = positionMapper.selectOpenByUser(uid);
        double unrealized = 0;
        for (Position p : open) if (p.getPnl() != null) unrealized += p.getPnl();
        double realized = positionMapper.sumClosedPnl(uid);
        out.put("positions", open);
        out.put("unrealizedPnl", round2(unrealized));
        out.put("realizedPnl", round2(realized));
        out.put("totalPnl", round2(realized + unrealized));

        // 订单统计 + 近期成交
        out.put("totalOrders", orderMapper.countByUser(uid));
        out.put("filledOrders", orderMapper.countByUserAndStatus(uid, "filled"));
        out.put("failedOrders", orderMapper.countByUserAndStatus(uid, "failed"));
        out.put("turnover", round2(orderMapper.sumFilledTurnover(uid)));
        out.put("recentOrders", orderMapper.selectByUser(uid, 20));

        // 信号时间线(仅当机器人绑定了监控)
        out.put("signalHistory", bot.getMonitorId() == null
                ? List.of() : signalLogMapper.selectRecent(bot.getMonitorId(), 30));

        return ApiResponse.success(out);
    }

    private double round2(double v) {
        return Math.round(v * 100) / 100.0;
    }

    private String actor(HttpServletRequest request) {
        return String.valueOf(request.getAttribute("username"));
    }
}
