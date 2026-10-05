package com.aiquant.service;

import lombok.Data;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 风控引擎
 *
 * 风控铁律(对应设计文档):
 *   1. 单笔亏损 ≤ 2%
 *   2. 日亏损 ≥ 3% 触发熔断
 *   3. 最大持仓数 5
 *   4. 检查间隔 10 分钟
 */
@Service
public class RiskEngine {

    @Value("${risk.single-loss-ratio:0.02}")
    private double singleLossRatio;

    @Value("${risk.daily-loss-circuit-breaker:0.03}")
    private double dailyLossCircuitBreaker;

    @Value("${risk.max-positions:5}")
    private int maxPositions;

    // 用户日累计亏损比例缓存: userId -> dailyLossPct
    private final Map<String, Double> dailyLossCache = new ConcurrentHashMap<>();

    // 用户当前持仓数: userId -> positionCount
    private final Map<String, Integer> positionCountCache = new ConcurrentHashMap<>();

    // 用户熔断状态: userId -> circuitBroken
    private final Map<String, Boolean> circuitBreakerStatus = new ConcurrentHashMap<>();

    /**
     * 下单前风控检查
     * @return 通过返回 null,拦截返回原因
     */
    public String checkOrder(OrderRequest order) {
        // 1. 持仓数检查
        int currentCount = positionCountCache.getOrDefault(order.getUserId(), 0);
        if (order.isNewPosition() && currentCount >= maxPositions) {
            return "持仓数已达上限(" + maxPositions + "),不可新开仓";
        }

        // 2. 单笔风险检查(预计最大亏损 = 开仓金额 * singleLossRatio)
        double estimatedLoss = order.getAmount() * order.getEntryPrice() * singleLossRatio;
        if (order.getStopLossPrice() > 0) {
            double actualLoss = order.isLong()
                    ? (order.getEntryPrice() - order.getStopLossPrice()) * order.getAmount()
                    : (order.getStopLossPrice() - order.getEntryPrice()) * order.getAmount();
            if (actualLoss > estimatedLoss) {
                return "单笔预计亏损 " + actualLoss + " 超过上限 " + estimatedLoss;
            }
        }

        // 3. 日熔断检查
        if (Boolean.TRUE.equals(circuitBreakerStatus.get(order.getUserId()))) {
            return "今日已触发熔断,策略已暂停";
        }

        double dailyLoss = dailyLossCache.getOrDefault(order.getUserId(), 0.0);
        if (dailyLoss >= dailyLossCircuitBreaker) {
            circuitBreakerStatus.put(order.getUserId(), true);
            return "日亏损 " + (dailyLoss * 100) + "% 已触发熔断(" + (dailyLossCircuitBreaker * 100) + "%)";
        }

        return null;
    }

    /**
     * 记录盈亏
     */
    public void recordPnl(String userId, double pnlPct) {
        double current = dailyLossCache.getOrDefault(userId, 0.0);
        dailyLossCache.put(userId, current + pnlPct);

        // 触发熔断
        if (dailyLossCache.get(userId) >= dailyLossCircuitBreaker) {
            circuitBreakerStatus.put(userId, true);
            System.out.println("[RISK] 用户 " + userId + " 触发日亏损熔断!");
        }
    }

    /**
     * 更新持仓数
     */
    public void updatePositionCount(String userId, int delta) {
        int current = positionCountCache.getOrDefault(userId, 0);
        positionCountCache.put(userId, Math.max(0, current + delta));
    }

    /**
     * 重置日风控(每日收盘调用)
     */
    public void resetDaily() {
        dailyLossCache.clear();
        circuitBreakerStatus.clear();
        System.out.println("[RISK] 日风控已重置");
    }

    /**
     * 查询用户风控状态
     */
    public Map<String, Object> getRiskStatus(String userId) {
        return Map.of(
                "daily_loss_pct", dailyLossCache.getOrDefault(userId, 0.0),
                "position_count", positionCountCache.getOrDefault(userId, 0),
                "max_positions", maxPositions,
                "single_loss_ratio", singleLossRatio,
                "daily_circuit_breaker", dailyLossCircuitBreaker,
                "circuit_broken", circuitBreakerStatus.getOrDefault(userId, false)
        );
    }

    @Data
    public static class OrderRequest {
        private String userId;
        private String symbol;
        private boolean isLong;       // true=做多, false=做空
        private boolean isNewPosition; // true=新开仓, false=加仓
        private double amount;
        private double entryPrice;
        private double stopLossPrice;
    }
}
