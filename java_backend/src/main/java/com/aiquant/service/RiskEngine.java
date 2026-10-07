package com.aiquant.service;

import com.aiquant.mapper.PositionMapper;
import lombok.Data;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;

/**
 * 风控引擎
 *
 * 风控铁律(对应设计文档):
 *   1. 单笔亏损 ≤ 2%
 *   2. 日亏损 ≥ 3% 触发熔断
 *   3. 最大持仓数 5
 *   4. 检查间隔 10 分钟
 *
 * 状态持久化到 Redis(每日凌晨自动重置),避免服务重启丢失风控状态。
 */
@Service
public class RiskEngine {

    private static final String DAILY_LOSS_PREFIX = "risk:daily_loss:";
    private static final String CIRCUIT_PREFIX = "risk:circuit:";
    private static final String POS_COUNT_PREFIX = "risk:pos_count:";
    /** Redis 键 TTL 25 小时,确保跨日自动过期 */
    private static final long RISK_KEY_TTL_HOURS = 25;

    @Value("${risk.single-loss-ratio:0.02}")
    private double singleLossRatio;

    @Value("${risk.daily-loss-circuit-breaker:0.03}")
    private double dailyLossCircuitBreaker;

    @Value("${risk.max-positions:5}")
    private int maxPositions;

    @Autowired
    private StringRedisTemplate redisTemplate;

    @Autowired
    private PositionMapper positionMapper;

    /**
     * 下单前风控检查
     * @return 通过返回 null,拦截返回原因
     */
    public String checkOrder(OrderRequest order) {
        // 1. 持仓数检查(从 DB 实时查询,避免缓存不一致)
        int currentCount = positionMapper.selectOpenByUser(order.getUserId()).size();
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

        // 3. 日熔断检查(Redis 持久化)
        String circuitKey = CIRCUIT_PREFIX + order.getUserId();
        if ("1".equals(redisTemplate.opsForValue().get(circuitKey))) {
            return "今日已触发熔断,策略已暂停";
        }

        double dailyLoss = getDailyLoss(order.getUserId());
        if (dailyLoss >= dailyLossCircuitBreaker) {
            redisTemplate.opsForValue().set(circuitKey, "1", RISK_KEY_TTL_HOURS, TimeUnit.HOURS);
            return "日亏损 " + (dailyLoss * 100) + "% 已触发熔断(" + (dailyLossCircuitBreaker * 100) + "%)";
        }

        return null;
    }

    /**
     * 记录盈亏(持久化到 Redis)
     */
    public void recordPnl(String userId, double pnlPct) {
        String key = DAILY_LOSS_PREFIX + userId;
        double current = getDailyLoss(userId);
        double updated = current + pnlPct;
        redisTemplate.opsForValue().set(key, String.valueOf(updated), RISK_KEY_TTL_HOURS, TimeUnit.HOURS);

        // 触发熔断
        if (updated >= dailyLossCircuitBreaker) {
            redisTemplate.opsForValue().set(CIRCUIT_PREFIX + userId, "1", RISK_KEY_TTL_HOURS, TimeUnit.HOURS);
            System.out.println("[RISK] 用户 " + userId + " 触发日亏损熔断!");
        }
    }

    private double getDailyLoss(String userId) {
        String val = redisTemplate.opsForValue().get(DAILY_LOSS_PREFIX + userId);
        if (val == null) return 0.0;
        try {
            return Double.parseDouble(val);
        } catch (NumberFormatException e) {
            return 0.0;
        }
    }

    /**
     * 重置日风控(每日凌晨 0:05 自动调用,Redis 键 25h TTL 也会自动过期)
     * 同时主动 SCAN 并删除残留键,确保状态干净
     */
    @Scheduled(cron = "0 5 0 * * ?")
    public void resetDaily() {
        Set<String> keysToDelete = new HashSet<>();
        scanKeys(DAILY_LOSS_PREFIX + "*", keysToDelete);
        scanKeys(CIRCUIT_PREFIX + "*", keysToDelete);
        if (!keysToDelete.isEmpty()) {
            redisTemplate.delete(keysToDelete);
        }
        System.out.println("[RISK] 日风控已重置,清理残留键 " + keysToDelete.size() + " 个");
    }

    private void scanKeys(String pattern, Set<String> collector) {
        org.springframework.data.redis.core.Cursor<String> cursor =
                redisTemplate.scan(org.springframework.data.redis.core.ScanOptions.scanOptions()
                        .match(pattern).count(100).build());
        while (cursor.hasNext()) {
            collector.add(cursor.next());
        }
        cursor.close();
    }

    /**
     * 查询用户风控状态
     */
    public Map<String, Object> getRiskStatus(String userId) {
        int posCount = positionMapper.selectOpenByUser(userId).size();
        return Map.of(
                "daily_loss_pct", getDailyLoss(userId),
                "position_count", posCount,
                "max_positions", maxPositions,
                "single_loss_ratio", singleLossRatio,
                "daily_circuit_breaker", dailyLossCircuitBreaker,
                "circuit_broken", "1".equals(redisTemplate.opsForValue().get(CIRCUIT_PREFIX + userId))
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
