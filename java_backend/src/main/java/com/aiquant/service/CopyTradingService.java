package com.aiquant.service;

import com.aiquant.mapper.PositionMapper;
import com.aiquant.mapper.CopyTradeMapper;
import com.aiquant.mapper.StrategyFollowMapper;
import com.aiquant.mapper.StrategyPublishMapper;
import com.aiquant.mapper.MonitorMapper;
import com.aiquant.mapper.AlertMapper;
import com.aiquant.mapper.FuturesPositionMapper;
import com.aiquant.model.Monitor;
import com.aiquant.model.CopyTrade;
import com.aiquant.model.Alert;
import com.aiquant.model.Order;
import com.aiquant.model.Position;
import com.aiquant.model.Quote;
import com.aiquant.model.StrategyFollow;
import com.aiquant.model.StrategyPublish;
import com.aiquant.model.FuturesPosition;
import com.aiquant.model.FuturesOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 跟单系统:会员发布策略(需后台审核) + 他人按比例跟单复制。
 *
 * 复制语义(现货 long-only,与监控执行对齐):
 *   leader 买入 → follower 买单量 = leader 成交量 × ratio%(A 股取整手/加密 1e-6,
 *                 按 follower 可用余额截断,名义额 <5 跳过);
 *   leader 卖出 → follower 直接平自己在该标的多仓(加密全平;A 股只卖可卖份额,T+1 天然满足)。
 * 单 follower 复制失败只打日志,不影响其他 follower 与 leader 本身。
 */
@Service
public class CopyTradingService {

    private static final Set<Integer> RATIOS = Set.of(10, 25, 50, 100);
    /** 复制买单最小名义额(低于则跳过,避免无效碎单) */
    private static final double MIN_NOTIONAL = 5.0;

    @Autowired private StrategyPublishMapper publishMapper;
    @Autowired private StrategyFollowMapper followMapper;
    @Autowired private MonitorMapper monitorMapper;
    @Autowired private TradingService tradingService;
    @Autowired private MarketService marketService;
    @Autowired private PositionMapper positionMapper;
    @Autowired private CopyTradeMapper copyTradeMapper;
    @Autowired private AlertMapper alertMapper;
    @Autowired private FuturesService futuresService;
    @Autowired private FuturesPositionMapper futuresPositionMapper;

    // ══════════════ 发布 ══════════════

    /** 申请发布(已有记录则更新并重新进入待审核) */
    public StrategyPublish publish(String userId, Long monitorId, String title, String description) {
        Monitor monitor = monitorMapper.selectByIdAndUser(monitorId, userId);
        if (monitor == null) throw new RuntimeException("监控不存在");
        if (title == null || title.isBlank()) throw new RuntimeException("请填写策略标题");
        title = title.trim();
        if (title.length() > 50) throw new RuntimeException("标题不能超过 50 字");
        String desc = description == null ? "" : description.trim();
        if (desc.length() > 200) throw new RuntimeException("描述不能超过 200 字");

        StrategyPublish existing = publishMapper.selectByLeaderAndMonitor(userId, monitorId);
        if (existing != null) {
            publishMapper.resubmit(existing.getId(), title, desc);
        } else {
            StrategyPublish p = new StrategyPublish();
            p.setLeaderId(userId);
            p.setMonitorId(monitorId);
            p.setTitle(title);
            p.setDescription(desc);
            p.setStrategy(monitor.getStrategy());
            p.setSymbol(monitor.getSymbol());
            publishMapper.insert(p);
        }
        return publishMapper.selectByLeaderAndMonitor(userId, monitorId);
    }

    /** 我的发布列表(含审核状态) */
    public List<StrategyPublish> myPublishes(String userId) {
        return publishMapper.selectByLeader(userId);
    }

    /** 策略广场:仅审核通过的发布,附跟单人数 */
    public List<StrategyPublish> listPublished() {
        List<StrategyPublish> list = publishMapper.selectPublished();
        Map<Long, Long> counts = followerCounts();
        for (StrategyPublish p : list) {
            p.setFollowers(counts.getOrDefault(p.getId(), 0L));
        }
        return list;
    }

    private Map<Long, Long> followerCounts() {
        Map<Long, Long> counts = new HashMap<>();
        for (Map<String, Object> row : publishMapper.countFollowersGrouped()) {
            counts.put(((Number) row.get("publish_id")).longValue(),
                    ((Number) row.get("followers")).longValue());
        }
        return counts;
    }

    /** 下架:仅本人,同时停止相关跟单 */
    public void unpublish(String userId, Long publishId) {
        StrategyPublish p = publishMapper.selectById(publishId);
        if (p == null || !p.getLeaderId().equals(userId)) throw new RuntimeException("发布不存在");
        publishMapper.updateStatus(publishId, "offline");
        followMapper.stopByPublishId(publishId);
    }

    // ══════════════ 跟单 ══════════════

    /**
     * 跟单。mode: ratio=固定比例(10/25/50/100) / balance=本金比例(按双方可用资金实时换算)
     * / fixed=固定倍数(multiplier 0.1~10)。mode 为空时按旧规则固定比例兼容。
     */
    public StrategyFollow follow(String userId, Long publishId, String mode, Integer ratio, Double multiplier) {
        StrategyPublish p = publishMapper.selectById(publishId);
        if (p == null || !"published".equals(p.getStatus())) throw new RuntimeException("该策略不可跟单");
        if (p.getLeaderId().equals(userId)) throw new RuntimeException("不能跟单自己的策略");

        String m = mode == null || mode.isBlank() ? "ratio" : mode;
        Double fixedMul = null;
        switch (m) {
            case "ratio" -> {
                if (ratio == null || !RATIOS.contains(ratio)) throw new RuntimeException("跟单比例不合法(10/25/50/100)");
            }
            case "balance" -> ratio = 100; // 本金比例模式实时换算,ratio 列冗余存 100
            case "fixed" -> {
                if (multiplier == null || multiplier < 0.1 || multiplier > 10) {
                    throw new RuntimeException("跟随倍数需在 0.1-10 之间");
                }
                fixedMul = multiplier;
                ratio = (int) Math.round(multiplier * 100); // 冗余展示字段
            }
            default -> throw new RuntimeException("跟单模式不合法(ratio/balance/fixed)");
        }

        StrategyFollow existing = followMapper.selectByUserAndPublish(userId, publishId);
        if (existing != null) {
            // 更新时检查策略是否仍为发布状态(已下架不可更新)
            if (!"published".equals(p.getStatus())) {
                throw new RuntimeException("该策略已下架,不可更新跟单");
            }
            followMapper.updateFollow(existing.getId(), ratio, m, fixedMul == null ? 1.0 : fixedMul);
        } else {
            StrategyFollow f = new StrategyFollow();
            f.setUserId(userId);
            f.setPublishId(publishId);
            f.setLeaderId(p.getLeaderId());
            f.setMonitorId(p.getMonitorId());
            f.setRatio(ratio);
            f.setMode(m);
            f.setFixedMultiplier(fixedMul == null ? 1.0 : fixedMul);
            followMapper.insert(f);
        }
        return followMapper.selectByUserAndPublish(userId, publishId);
    }

    public List<StrategyFollow> myFollows(String userId) {
        return followMapper.selectByUser(userId);
    }

    public void stopFollow(String userId, Long followId) {
        if (followMapper.stopByIdAndUser(followId, userId) == 0) {
            throw new RuntimeException("跟单不存在");
        }
    }

    // ══════════════ 复制执行 ══════════════

    /**
     * leader 监控真实成交后,把本次买卖按跟单模式复制给所有 active 跟单者。
     * 由 MonitorExecutionService 在 leader 下单受理后调用。
     *
     * @param leaderAvail leader 下单前的可用余额(下单前获取,避免余额已被扣减导致比例失真)
     */
    public void replicate(Monitor monitor, String side, Order leaderOrder, Double leaderAvail) {
        List<StrategyFollow> follows = followMapper.selectActiveByMonitor(monitor.getId());
        if (follows.isEmpty()) return;
        Quote quote = marketService.getQuote(monitor.getSymbol());
        if (quote == null) return;
        double leaderQty = leaderOrder.getFilledAmount() == null ? 0 : leaderOrder.getFilledAmount();
        if (leaderQty <= 0) return;

        for (StrategyFollow f : follows) {
            try {
                if ("buy".equals(side)) {
                    copyBuy(f, monitor, leaderQty, quote, factorOf(f, quote, leaderAvail));
                } else if ("sell".equals(side)) {
                    // 监控自动卖出语义保持:加密全平;A 股只卖可卖份额(T+1 天然满足)
                    copySell(f, monitor, quote, null, factorOf(f, quote, leaderAvail));
                }
            } catch (Exception e) {
                alertSkip(f, monitor, "复制失败: " + e.getMessage());
            }
        }
    }

    /** 向后兼容:未传 leaderAvail 时实时获取(精度略低) */
    public void replicate(Monitor monitor, String side, Order leaderOrder) {
        Quote quote = marketService.getQuote(monitor.getSymbol());
        Double avail = quote != null ? leaderAvail(monitor.getUserId(), quote) : null;
        replicate(monitor, side, leaderOrder, avail);
    }

    // ══════════════ 个人策略信号分发(人工触发) ══════════════

    /** 分发开多/加仓:leader 已成交数量 → follower 按模式换算买入 */
    public Map<String, Object> replicatePersonalBuy(Monitor m, double leaderFilledQty) {
        Quote quote = marketService.getQuote(m.getSymbol());
        Double leaderAvail = leaderAvail(m.getUserId(), quote);
        return distribute(m, quote, leaderAvail, (f) -> {
            copyBuy(f, m, leaderFilledQty, quote, factorOf(f, quote, leaderAvail));
            return true;
        });
    }

    /** 分发平仓:leaderSellQty=null 全平;否则按模式换算部分平仓 */
    public Map<String, Object> replicatePersonalSell(Monitor m, Double leaderSellQty) {
        Quote quote = marketService.getQuote(m.getSymbol());
        Double leaderAvail = leaderAvail(m.getUserId(), quote);
        return distribute(m, quote, leaderAvail, (f) -> {
            copySell(f, m, quote, leaderSellQty, factorOf(f, quote, leaderAvail));
            return true;
        });
    }

    /** 分发开空:follower 合约开空(保证金不足/已有反向仓则跳过并告警) */
    public Map<String, Object> replicatePersonalShort(Monitor m, double leaderAmount, int leverage) {
        Quote quote = marketService.getQuote(m.getSymbol());
        Double leaderAvail = leaderAvail(m.getUserId(), quote);
        return distribute(m, quote, leaderAvail, (f) -> {
            double qty = floorByMarket(leaderAmount * factorOf(f, quote, leaderAvail), quote.getMarket());
            if (qty <= 0) throw new RuntimeException("换算数量为 0");
            futuresService.openPosition(f.getUserId(), m.getSymbol(), "short", leverage, qty);
            recordRaw(f, m, "short", qty, quote.getPrice(), null);
            return true;
        });
    }

    /** 分发平空:leaderCloseQty=null 全平;否则按模式换算 */
    public Map<String, Object> replicatePersonalCloseShort(Monitor m, Double leaderCloseQty) {
        Quote quote = marketService.getQuote(m.getSymbol());
        Double leaderAvail = leaderAvail(m.getUserId(), quote);
        return distribute(m, quote, leaderAvail, (f) -> {
            FuturesPosition fp = futuresPositionMapper.selectOpenBySymbol(f.getUserId(), m.getSymbol());
            if (fp == null || !"short".equals(fp.getDirection())) return false; // 无空头,静默跳过
            double qty = leaderCloseQty == null ? fp.getAmount()
                    : Math.min(floorByMarket(leaderCloseQty * factorOf(f, quote, leaderAvail), quote.getMarket()),
                            fp.getAmount());
            if (qty <= 0) throw new RuntimeException("可平数量为 0");
            FuturesOrder fo = futuresService.closePosition(f.getUserId(), fp.getId(), qty);
            recordRaw(f, m, "close_short", qty, fo.getPrice() == null ? 0 : fo.getPrice(), fo.getPnl());
            return true;
        });
    }

    /** 遍历 active 跟单者执行复制动作,统计成功/跳过(失败隔离 + 告警) */
    private Map<String, Object> distribute(Monitor m, Quote quote, Double leaderAvail,
                                           java.util.function.Function<StrategyFollow, Boolean> action) {
        List<StrategyFollow> follows = followMapper.selectActiveByMonitor(m.getId());
        int ok = 0, skip = 0;
        List<String> details = new ArrayList<>();
        for (StrategyFollow f : follows) {
            try {
                boolean executed = action.apply(f);
                if (executed) {
                    ok++;
                    details.add(f.getUserId() + " 成功");
                } else {
                    skip++;
                    details.add(f.getUserId() + " 无持仓");
                }
            } catch (Exception e) {
                skip++;
                details.add(f.getUserId() + " 失败");
                alertSkip(f, m, e.getMessage());
            }
        }
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("ok", ok);
        r.put("skip", skip);
        r.put("details", details);
        return r;
    }

    // ══════════════ 换算与工具 ══════════════

    /** 按 follow 关系的模式换算复制倍数(balance=follower/leader 可用资金比,fixed=倍数,ratio=比例%) */
    private double factorOf(StrategyFollow f, Quote quote, Double leaderAvail) {
        String mode = f.getMode() == null ? "ratio" : f.getMode();
        switch (mode) {
            case "fixed":
                return f.getFixedMultiplier() == null ? 1.0 : f.getFixedMultiplier();
            case "balance":
                if (leaderAvail == null || leaderAvail <= 0) return 0;
                return followerAvail(f.getUserId(), quote) / leaderAvail;
            default:
                return (f.getRatio() == null ? 10 : f.getRatio()) / 100.0;
        }
    }

    private Double leaderAvail(String userId, Quote quote) {
        try {
            Map<String, Object> ov = tradingService.getAccountOverview(userId, quote.getCurrency());
            return ((Number) ov.get("available")).doubleValue();
        } catch (Exception e) {
            return null;
        }
    }

    private double followerAvail(String userId, Quote quote) {
        try {
            Map<String, Object> ov = tradingService.getAccountOverview(userId, quote.getCurrency());
            return ((Number) ov.get("available")).doubleValue();
        } catch (Exception e) {
            return 0;
        }
    }

    /** 跳过/失败 → 站内告警(写失败仅日志) */
    private void alertSkip(StrategyFollow f, Monitor m, String reason) {
        System.out.println("[COPY] follower=" + f.getUserId() + " monitor=" + m.getId()
                + " 跳过: " + reason);
        try {
            Alert a = new Alert();
            a.setUserId(f.getUserId());
            a.setType("copy_skip");
            a.setTitle("跟单信号未执行");
            a.setContent("策略[" + m.getStrategy() + " · " + m.getSymbol() + "] " + reason);
            alertMapper.insert(a);
        } catch (Exception ignore) {
        }
    }

    /** 合约复制流水(t_copy_trade side=short/close_short) */
    private void recordRaw(StrategyFollow f, Monitor m, String side, double amount, double price, Double pnl) {
        try {
            CopyTrade t = new CopyTrade();
            t.setFollowId(f.getId());
            t.setUserId(f.getUserId());
            t.setPublishId(f.getPublishId());
            t.setMonitorId(m.getId());
            t.setSymbol(m.getSymbol());
            t.setSide(side);
            t.setAmount(amount);
            t.setPrice(price);
            t.setPnl(pnl);
            copyTradeMapper.insert(t);
        } catch (Exception e) {
            System.out.println("[COPY] 合约流水记录失败 follower=" + f.getUserId() + ": " + e.getMessage());
        }
    }

    private void copyBuy(StrategyFollow f, Monitor m, double leaderQty, Quote quote, double factor) {
        double qty = floorByMarket(leaderQty * factor, quote.getMarket());
        if (qty <= 0) throw new RuntimeException("换算数量为 0");

        // 按 follower 可用余额截断(留 0.5% 防市价漂移)
        double price = quote.getPrice();
        double available = followerAvail(f.getUserId(), quote);
        double maxQty = floorByMarket(available * 0.995 / price, quote.getMarket());
        qty = Math.min(qty, maxQty);
        if (qty <= 0 || qty * price < MIN_NOTIONAL) {
            throw new RuntimeException("余额不足或数量过小");
        }
        Order filled = tradingService.placeOrder(f.getUserId(), m.getSymbol(), "buy", "market", null, qty,
                "跟单:" + m.getStrategy());
        record(f, m, "buy", filled, null);
    }

    private void copySell(StrategyFollow f, Monitor m, Quote quote, Double leaderSellQty, double factor) {
        Position open = positionMapper.selectOpen(f.getUserId(), m.getSymbol(), "long");
        if (open == null) return; // follower 无该标的多仓,无需平(静默)
        boolean aShare = "a-share".equals(quote.getMarket());
        double cap = aShare
                ? (open.getAvailableAmount() == null ? 0 : open.getAvailableAmount())
                : open.getAmount();
        double qty;
        if (leaderSellQty == null) {
            qty = cap; // 全平语义:加密全平;A 股只卖可卖份额(T+1)
        } else {
            qty = Math.min(floorByMarket(leaderSellQty * factor, quote.getMarket()), cap);
        }
        if (qty <= 0) throw new RuntimeException("可平数量为 0");
        Order filled = tradingService.placeOrder(f.getUserId(), m.getSymbol(), "sell", "market", null, qty,
                "跟单:" + m.getStrategy());
        // 已实现盈亏 = (成交价 - 持仓均价) × 卖出数量
        Double pnl = null;
        if (filled != null && filled.getPrice() != null && open.getEntryPrice() != null) {
            pnl = (filled.getPrice() - open.getEntryPrice()) * qty;
        }
        record(f, m, "sell", filled, pnl);
    }

    /** 复制成交后落流水;记录失败不影响交易本身 */
    private void record(StrategyFollow f, Monitor m, String side, Order filled, Double pnl) {
        try {
            if (filled == null || filled.getPrice() == null) return;
            CopyTrade t = new CopyTrade();
            t.setFollowId(f.getId());
            t.setUserId(f.getUserId());
            t.setPublishId(f.getPublishId());
            t.setMonitorId(m.getId());
            t.setSymbol(m.getSymbol());
            t.setSide(side);
            t.setAmount(filled.getFilledAmount() == null ? 0 : filled.getFilledAmount());
            t.setPrice(filled.getPrice());
            t.setPnl(pnl);
            t.setOrderId(filled.getOrderId());
            copyTradeMapper.insert(t);
        } catch (Exception e) {
            System.out.println("[COPY] 流水记录失败 follower=" + f.getUserId() + ": " + e.getMessage());
        }
    }

    /** A 股向下取整手(100 股);加密向下取 6 位小数 */
    public double floorByMarket(double qty, String market) {
        if ("a-share".equals(market)) {
            return Math.floor(qty / 100.0) * 100;
        }
        return Math.floor(qty * 1e6) / 1e6;
    }
}
