package com.aiquant.service.ai;

import com.aiquant.mapper.MonitorMapper;
import com.aiquant.mapper.PositionMapper;
import com.aiquant.mapper.UserMapper;
import com.aiquant.model.Monitor;
import com.aiquant.model.Position;
import com.aiquant.model.Quote;
import com.aiquant.model.User;
import com.aiquant.service.MarketService;
import com.aiquant.service.TradingService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * AI 自动执行编排:对 running 监控调用 Python 五因子决策,并把信号落地为交易。
 *
 * 现货 long-only 语义:
 *   open_long 且无持仓 → 市价买入(单笔≈可用余额 9.5%);
 *   open_short 且持多仓 → 市价全部卖出平仓(做空信号=平多);
 *   reject/wait → 仅回写信号。
 * 守卫:持仓状态防重复开/平;30s 冷却;单笔异常不影响其他监控。
 */
@Service
public class MonitorExecutionService {

    /** 下单冷却(毫秒),仅约束真实下单动作 */
    private static final long COOLDOWN_MS = 30_000;
    /** 单次 AI 建仓占用可用余额比例(留 0.5% 防市价漂移致余额校验失败) */
    private static final double BUY_NOTIONAL_RATIO = 0.095;
    private static final int SIGNAL_LEN = 50; // t_monitor.signal VARCHAR(50)

    @Autowired private MonitorMapper monitorMapper;
    @Autowired private MarketService marketService;
    @Autowired private TradingService tradingService;
    @Autowired private PositionMapper positionMapper;
    @Autowired private UserMapper userMapper;
    @Autowired private AiDecisionGateway aiGateway;

    private final Map<Long, Long> cooldownUntil = new ConcurrentHashMap<>();

    /** 执行一轮:扫描全部 running 监控 */
    public void executeAll() {
        List<Monitor> running = monitorMapper.selectRunning();
        for (Monitor m : running) {
            try {
                executeOne(m);
            } catch (Exception e) {
                // 单监控失败隔离,不影响其他监控本轮执行
                System.out.println("[AI-EXEC] monitor=" + m.getId() + " 异常: " + e.getMessage());
            }
        }
    }

    private void executeOne(Monitor m) {
        Quote quote = marketService.getQuote(m.getSymbol());
        if (quote == null) return;
        User user = userMapper.selectByUserId(m.getUserId());
        if (user == null) return;

        // 1. 组装历史序列(K线 5m×60 的 close/volume)
        List<Map<String, Object>> bars = marketService.getKline(m.getSymbol(), "5m", 60);
        List<Double> closes = new ArrayList<>();
        List<Double> volumes = new ArrayList<>();
        for (Map<String, Object> bar : bars) {
            closes.add(((Number) bar.get("close")).doubleValue());
            volumes.add(((Number) bar.get("volume")).doubleValue());
        }

        // 2. 当前持仓状态
        Position open = positionMapper.selectOpen(m.getUserId(), m.getSymbol(), "long");

        // 3. 调 AI 决策
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("symbol", m.getSymbol());
        payload.put("current_price", quote.getPrice());
        payload.put("historical_prices", closes);
        payload.put("volume_history", volumes);
        payload.put("position_side", open != null ? "long" : null);
        payload.put("risk_level", user.getRiskLevel() != null ? user.getRiskLevel() : "R3");

        Map<String, Object> decision = aiGateway.decide(payload);
        if (decision == null) return; // AI 离线/超时:不覆盖信号,下轮再试

        String action = String.valueOf(decision.get("action"));
        String reason = decision.get("reason") == null ? "" : decision.get("reason").toString();
        long now = System.currentTimeMillis();
        boolean cooled = now >= cooldownUntil.getOrDefault(m.getId(), 0L);

        // 4. 信号 → 交易
        switch (action) {
            case "open_long":
                if (open != null) {
                    writeSignal(m, "AI已持多仓,观望");
                } else if (!cooled) {
                    // 冷却期跳过下单
                } else {
                    double amount = buyAmount(m.getUserId(), quote);
                    if (amount <= 0) {
                        writeSignal(m, "AI买入信号,余额不足");
                    } else {
                        tradingService.placeOrder(m.getUserId(), m.getSymbol(), "buy",
                                "market", null, amount, "AI:" + m.getStrategy());
                        cooldownUntil.put(m.getId(), now + COOLDOWN_MS);
                        writeSignal(m, "AI买入@" + fmt(quote.getPrice()));
                    }
                }
                break;
            case "open_short":
                if (open == null) {
                    writeSignal(m, "AI做空信号,无多仓");
                } else if (!cooled) {
                    // 冷却期跳过
                } else {
                    // A股 T+1:只卖可卖份额(当日买入冻结),加密全平
                    double sellQty = "a-share".equals(quote.getMarket())
                            ? (open.getAvailableAmount() == null ? 0 : open.getAvailableAmount())
                            : open.getAmount();
                    if (sellQty <= 0) {
                        writeSignal(m, "A股T+1,当日买入次日可卖");
                    } else {
                        tradingService.placeOrder(m.getUserId(), m.getSymbol(), "sell",
                                "market", null, sellQty, "AI:" + m.getStrategy());
                        cooldownUntil.put(m.getId(), now + COOLDOWN_MS);
                        writeSignal(m, "AI平仓@" + fmt(quote.getPrice()));
                    }
                }
                break;
            case "reject":
                writeSignal(m, "AI拦截:" + reason);
                break;
            case "wait":
                writeSignal(m, "AI观望:" + reason);
                break;
            default:
                break;
        }
    }

    /**
     * 按对应币种可用余额 9.5% 折算可买数量。
     * A股:再向下取整到整手(100股),不足 1 手返回 0;加密:向下取 6 位小数。
     */
    private double buyAmount(String userId, Quote quote) {
        Map<String, Object> overview =
                tradingService.getAccountOverview(userId, quote.getCurrency());
        double available = ((Number) overview.get("available")).doubleValue();
        double price = quote.getPrice();
        if (available <= 0 || price <= 0) return 0;
        double amount = available * BUY_NOTIONAL_RATIO / price;
        if ("a-share".equals(quote.getMarket())) {
            double lots = Math.floor(amount / 100.0);
            return lots * 100;
        }
        return Math.floor(amount * 1e6) / 1e6;
    }

    private void writeSignal(Monitor m, String signal) {
        if (signal.length() > SIGNAL_LEN) {
            signal = signal.substring(0, SIGNAL_LEN);
        }
        monitorMapper.updateSignal(m.getId(), signal);
    }

    private String fmt(double price) {
        return price >= 1000
                ? String.format("%.0f", price)
                : String.format("%.2f", price);
    }
}
