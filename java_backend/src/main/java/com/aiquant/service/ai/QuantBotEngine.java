package com.aiquant.service.ai;

import com.aiquant.mapper.BotGridLevelMapper;
import com.aiquant.mapper.MonitorMapper;
import com.aiquant.mapper.PositionMapper;
import com.aiquant.mapper.QuantBotMapper;
import com.aiquant.mapper.SignalLogMapper;
import com.aiquant.model.BotGridLevel;
import com.aiquant.model.Monitor;
import com.aiquant.model.Order;
import com.aiquant.model.Position;
import com.aiquant.model.QuantBot;
import com.aiquant.model.SignalLog;
import com.aiquant.model.Quote;
import com.aiquant.service.CopyTradingService;
import com.aiquant.service.MarketService;
import com.aiquant.service.TradingService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 开源策略量化机器人引擎:机器人作为虚拟带单员自动运行,
 * 信号成交后复用跟单管道(copyTradingService.replicate)复制给所有跟单用户。
 *
 * 策略(参考 freqtrade / Hummingbot 开源实现):
 *   ema_cross  EMA12/26 金叉买入、死叉卖出(15m)
 *   rsi_rev    RSI14 <30 买入、>70 卖出(15m)
 *   boll_break 收盘价突破布林上轨买入、跌回中轨卖出(15m)
 *   grid       2% 间距 5 档网格,触及档位自动低买高卖
 * 单机器人异常隔离;K线/行情不可用时本轮跳过。
 */
@Service
public class QuantBotEngine {

    private static final String KLINE_PERIOD = "15m";
    private static final int KLINE_LIMIT = 100;
    private static final double MIN_NOTIONAL = 5.0;

    private static final int SIGNAL_LEN = 50;

    // 指标/网格参数不再写死:统一走 BotParamSchema 默认值,运行时可被 config_json 覆盖。
    // 下方常量仅作为“模式未定义该键”时的最终兵底。

    @Autowired private QuantBotMapper botMapper;
    @Autowired private MonitorMapper monitorMapper;
    @Autowired private MarketService marketService;
    @Autowired private TradingService tradingService;
    @Autowired private PositionMapper positionMapper;
    @Autowired private BotGridLevelMapper gridLevelMapper;
    @Autowired private CopyTradingService copyTradingService;
    @Autowired private SignalLogMapper signalLogMapper;
    @Autowired private ObjectMapper objectMapper;

    /** 执行一轮全部机器人 */
    public void executeAll() {
        for (QuantBot bot : botMapper.selectAll()) {
            try {
                Monitor m = monitorMapper.selectByIdAndUser(bot.getMonitorId(), bot.getBotUserId());
                if (m == null || !"running".equals(m.getStatus())) continue;
                Quote quote = marketService.getQuote(bot.getSymbol());
                if (quote == null) continue;
                if ("grid".equals(bot.getStrategyKey())) {
                    runGrid(bot, m, quote);
                } else {
                    runIndicator(bot, m, quote);
                }
            } catch (Exception e) {
                System.out.println("[BOT] " + bot.getStrategyKey() + " " + bot.getSymbol()
                        + " 本轮异常: " + e.getMessage());
            }
        }
    }

    // ══════════════ 指标类机器人 ══════════════

    private void runIndicator(QuantBot bot, Monitor m, Quote quote) {
        List<Map<String, Object>> bars =
                marketService.getKline(bot.getSymbol(), KLINE_PERIOD, KLINE_LIMIT);
        if (bars == null || bars.size() < 30) return;
        List<Double> closes = new ArrayList<>();
        for (Map<String, Object> bar : bars) {
            closes.add(((Number) bar.get("close")).doubleValue());
        }
        Position open = positionMapper.selectOpen(bot.getBotUserId(), bot.getSymbol(), "long");
        double price = quote.getPrice();
        int last = closes.size() - 1;
        JsonNode cfg = parseCfg(bot);

        String decision = null; // "buy" / "sell" / null
        String note = "";

        switch (bot.getStrategyKey()) {
            case "ema_cross": {
                double[] fast = IndicatorCalc.ema(closes, (int) p(cfg, "ema_cross", "emaFast", 12));
                double[] slow = IndicatorCalc.ema(closes, (int) p(cfg, "ema_cross", "emaSlow", 26));
                boolean golden = fast[last - 1] <= slow[last - 1] && fast[last] > slow[last];
                boolean death = fast[last - 1] >= slow[last - 1] && fast[last] < slow[last];
                if (golden) decision = "buy";
                if (death) decision = "sell";
                note = String.format("EMA %.0f/%.0f %s", fast[last], slow[last],
                        fast[last] > slow[last] ? "多头排列" : "空头排列");
                break;
            }
            case "rsi_rev": {
                double[] rsi = IndicatorCalc.rsi(closes, (int) p(cfg, "rsi_rev", "rsiPeriod", 14));
                double r = rsi[last];
                double buyBelow = p(cfg, "rsi_rev", "rsiBuyBelow", 30);
                double sellAbove = p(cfg, "rsi_rev", "rsiSellAbove", 70);
                if (r < buyBelow) decision = "buy";
                if (r > sellAbove) decision = "sell";
                note = String.format("RSI %.1f %s", r, r < buyBelow ? "超卖" : r > sellAbove ? "超买" : "中性");
                break;
            }
            case "boll_break": {
                double[] bb = IndicatorCalc.bollinger(closes, (int) p(cfg, "boll_break", "bbPeriod", 20),
                        p(cfg, "boll_break", "bbMult", 2));
                double c = closes.get(last);
                if (c > bb[1]) decision = "buy";
                if (c < bb[0]) decision = "sell";
                note = String.format("价%.0f 轨[%.0f/%.0f]", c, bb[2], bb[1]);
                break;
            }
            default:
                return;
        }

        if ("buy".equals(decision) && open == null) {
            double qty = floor6(buyAvailable(bot.getBotUserId())
                    * p(cfg, bot.getStrategyKey(), "buyRatio", 0.95) / price);
            if (qty <= 0 || qty * price < MIN_NOTIONAL) {
                writeSignal(m, "机器人买入信号,余额不足");
                return;
            }
            Order order = tradingService.placeOrder(bot.getBotUserId(), bot.getSymbol(), "buy",
                    "market", null, qty, "机器人:" + bot.getStrategyKey());
            copyTradingService.replicate(m, "buy", order);
            writeSignal(m, "机器人买入@" + fmt(price));
        } else if ("sell".equals(decision) && open != null) {
            double qty = open.getAmount() == null ? 0 : open.getAmount();
            if (qty <= 0) {
                writeSignal(m, "机器人卖出信号,无持仓");
                return;
            }
            Order order = tradingService.placeOrder(bot.getBotUserId(), bot.getSymbol(), "sell",
                    "market", null, qty, "机器人:" + bot.getStrategyKey());
            copyTradingService.replicate(m, "sell", order);
            writeSignal(m, "机器人卖出@" + fmt(price));
        } else {
            writeSignal(m, note);
        }
    }

    // ══════════════ 网格机器人 ══════════════

    private void runGrid(QuantBot bot, Monitor m, Quote quote) {
        JsonNode cfg = parseCfg(bot);
        double step = p(cfg, "grid", "gridStep", 0.02);
        int depth = (int) p(cfg, "grid", "gridDepth", 5);
        double slice = p(cfg, "grid", "gridSlice", 500);

        // 首次运行:以当前价为锚向下布 depth 档买单
        if (gridLevelMapper.countByMonitor(m.getId()) == 0) {
            double anchor = quote.getPrice();
            for (int k = 1; k <= depth; k++) {
                insertLevel(m.getId(), k, anchor * (1 - k * step), "buy", 0.0, "open");
            }
            writeSignal(m, String.format("网格建仓 锚%.0f %d档", anchor, depth));
            return;
        }

        double price = quote.getPrice();
        List<BotGridLevel> openLevels = gridLevelMapper.selectOpenByMonitor(m.getId());

        // 买入:价格跌到触发价及以下的档位中,取离现价最近(触发价最高)的一档
        BotGridLevel buyPick = null;
        for (BotGridLevel lv : openLevels) {
            if ("buy".equals(lv.getSide()) && lv.getTriggerPrice() >= price
                    && (buyPick == null || lv.getTriggerPrice() < buyPick.getTriggerPrice())) {
                buyPick = lv;
            }
        }
        if (buyPick != null) {
            double qty = floor6(slice / price);
            if (qty <= 0 || qty * price < MIN_NOTIONAL) return;
            Order order = tradingService.placeOrder(bot.getBotUserId(), bot.getSymbol(), "buy",
                    "market", null, qty, "机器人:grid");
            double filled = order.getFilledAmount() == null ? 0 : order.getFilledAmount();
            // 仅在订单实际成交后更新档位状态,避免未成交导致档位浪费
            if (filled > 0) {
                gridLevelMapper.updateStatus(buyPick.getId(), "filled", filled);
                // 生成对应卖档:买档触发价 +1 格
                insertLevel(m.getId(), buyPick.getGridIdx(), buyPick.getTriggerPrice() * (1 + step),
                        "sell", filled, "open");
                copyTradingService.replicate(m, "buy", order);
                writeSignal(m, "网格买入@" + fmt(price));
            } else {
                writeSignal(m, "网格买入未成交,档位保留");
            }
            return;
        }

        // 卖出:价格涨到触发价及以上的档位中,取离现价最近(触发价最低)的一档
        BotGridLevel sellPick = null;
        for (BotGridLevel lv : openLevels) {
            if ("sell".equals(lv.getSide()) && lv.getTriggerPrice() <= price
                    && (sellPick == null || lv.getTriggerPrice() > sellPick.getTriggerPrice())) {
                sellPick = lv;
            }
        }
        if (sellPick != null) {
            Position pos = positionMapper.selectOpen(bot.getBotUserId(), bot.getSymbol(), "long");
            double qty = sellPick.getAmount() == null ? 0 : sellPick.getAmount();
            if (pos == null || pos.getAmount() == null || pos.getAmount() < qty) return;
            Order order = tradingService.placeOrder(bot.getBotUserId(), bot.getSymbol(), "sell",
                    "market", null, qty, "机器人:grid");
            double filled = order.getFilledAmount() == null ? 0 : order.getFilledAmount();
            // 仅在订单实际成交后更新档位状态
            if (filled > 0) {
                gridLevelMapper.updateStatus(sellPick.getId(), "closed", filled);
                // 重新武装对应买档:卖档触发价 -1 格
                insertLevel(m.getId(), sellPick.getGridIdx(), sellPick.getTriggerPrice() * (1 - step),
                        "buy", 0.0, "open");
                copyTradingService.replicate(m, "sell", order);
                writeSignal(m, "网格卖出@" + fmt(price));
            } else {
                writeSignal(m, "网格卖出未成交,档位保留");
            }
        }
    }

    private void insertLevel(long monitorId, int idx, double trigger, String side, double amount, String status) {
        BotGridLevel lv = new BotGridLevel();
        lv.setMonitorId(monitorId);
        lv.setGridIdx(idx);
        lv.setTriggerPrice(trigger);
        lv.setSide(side);
        lv.setAmount(amount);
        lv.setStatus(status);
        gridLevelMapper.insert(lv);
    }

    // ══════════════ 公共 ══════════════

    private double buyAvailable(String botUserId) {
        Map<String, Object> overview = tradingService.getAccountOverview(botUserId, "USDT");
        return ((Number) overview.get("available")).doubleValue();
    }

    private double floor6(double qty) {
        return Math.floor(qty * 1e6) / 1e6;
    }

    /** 解析机器人 config_json 为 JSON 对象树(空/非法返回空对象),供参数读取。 */
    private JsonNode parseCfg(QuantBot bot) {
        String raw = bot.getConfigJson();
        if (raw == null || raw.isBlank()) return objectMapper.createObjectNode();
        try {
            JsonNode node = objectMapper.readTree(raw);
            return node.isObject() ? node : objectMapper.createObjectNode();
        } catch (Exception e) {
            return objectMapper.createObjectNode();
        }
    }

    /** 读取数值参数:config_json 覆盖 > BotParamSchema 默认值 > 传入 fallback。 */
    private double p(JsonNode cfg, String strategy, String key, double fallback) {
        if (cfg != null && cfg.hasNonNull(key)) {
            JsonNode v = cfg.get(key);
            if (v.isNumber()) return v.doubleValue();
            if (v.isTextual()) {
                try {
                    return Double.parseDouble(v.asText().trim());
                } catch (Exception ignore) {
                    // 非法数值落回默认
                }
            }
        }
        return BotParamSchema.def(strategy, key, fallback);
    }

    private void writeSignal(Monitor m, String signal) {
        if (signal.length() > SIGNAL_LEN) signal = signal.substring(0, SIGNAL_LEN);
        monitorMapper.updateSignal(m.getId(), signal);
        // 落一条信号历史,供后台机器人绩效时间线
        SignalLog log = new SignalLog();
        log.setMonitorId(m.getId());
        log.setUserId(m.getUserId());
        log.setAction(deriveAction(signal));
        log.setSignal(signal);
        signalLogMapper.insert(log);
    }

    /** 由信号文案粗分类动作,便于时间线着色/筛选 */
    private String deriveAction(String signal) {
        if (signal.contains("买入")) return "open_long";
        if (signal.contains("卖出") || signal.contains("平仓")) return "close";
        return "hold";
    }

    private String fmt(double price) {
        return price >= 1000
                ? String.format("%.0f", price)
                : String.format("%.2f", price);
    }
}
