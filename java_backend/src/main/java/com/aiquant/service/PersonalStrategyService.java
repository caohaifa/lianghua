package com.aiquant.service;

import com.aiquant.mapper.AlertMapper;
import com.aiquant.mapper.FuturesPositionMapper;
import com.aiquant.mapper.MonitorMapper;
import com.aiquant.mapper.PersonalSignalMapper;
import com.aiquant.mapper.PositionMapper;
import com.aiquant.mapper.StrategyFollowMapper;
import com.aiquant.mapper.SystemConfigMapper;
import com.aiquant.model.Alert;
import com.aiquant.model.FuturesOrder;
import com.aiquant.model.FuturesPosition;
import com.aiquant.model.Monitor;
import com.aiquant.model.Order;
import com.aiquant.model.PersonalSignal;
import com.aiquant.model.Position;
import com.aiquant.model.Quote;
import com.aiquant.model.StrategyFollow;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 个人策略:人工配置、人工触发。主交易员在信号台下发信号(开多/加仓/部分平仓/全部平仓/开空),
 * 机器人按跟单模式(本金比例/固定倍数/固定比例)自动为全部跟单用户换算仓位执行。
 * 全局风控开关(copy_trading_paused)可一键暂停全部分发;follower 也可单独暂停自己的跟单。
 */
@Service
public class PersonalStrategyService {

    private static final Set<String> ACTIONS =
            Set.of("open_long", "add_long", "partial_close", "close_all", "open_short");

    @Autowired private MonitorMapper monitorMapper;
    @Autowired private MarketService marketService;
    @Autowired private TradingService tradingService;
    @Autowired private PositionMapper positionMapper;
    @Autowired private FuturesService futuresService;
    @Autowired private FuturesPositionMapper futuresPositionMapper;
    @Autowired private CopyTradingService copyTradingService;
    @Autowired private SystemConfigMapper systemConfigMapper;
    @Autowired private PersonalSignalMapper signalMapper;
    @Autowired private AlertMapper alertMapper;
    @Autowired private StrategyFollowMapper followMapper;

    /** 下发信号:leader 自身成交 → 按 follow 模式分发 → 信号落库 */
    public Map<String, Object> signal(String userId, Long monitorId, String action,
                                      Double amount, Integer ratioPct, Integer leverage) {
        checkGlobalNotPaused();
        Monitor monitor = monitorMapper.selectByIdAndUser(monitorId, userId);
        if (monitor == null) throw new RuntimeException("监控不存在");
        if (!"个人策略".equals(monitor.getStrategy())) throw new RuntimeException("仅个人策略支持人工信号");
        if (!"running".equals(monitor.getStatus())) throw new RuntimeException("监控已暂停,请先恢复运行再下发信号");
        if (!ACTIONS.contains(action)) throw new RuntimeException("信号动作不合法");
        Quote quote = marketService.getQuote(monitor.getSymbol());
        if (quote == null) throw new RuntimeException("标的不存在或无行情");

        Map<String, Object> dist;
        switch (action) {
            case "open_long", "add_long" -> {
                if (amount == null || amount <= 0) throw new RuntimeException("开仓数量必须大于 0");
                Order filled = tradingService.placeOrder(userId, monitor.getSymbol(),
                        "buy", "market", null, amount, "个人策略");
                if (filled == null || filled.getFilledAmount() == null || filled.getFilledAmount() <= 0) {
                    throw new RuntimeException("买入未成交");
                }
                dist = copyTradingService.replicatePersonalBuy(monitor, filled.getFilledAmount());
            }
            case "partial_close" -> {
                if (ratioPct == null || ratioPct < 1 || ratioPct > 99) {
                    throw new RuntimeException("部分平仓比例需在 1-99");
                }
                dist = partialClose(userId, monitor, quote, ratioPct);
            }
            case "close_all" -> dist = closeAll(userId, monitor, quote);
            case "open_short" -> dist = openShort(userId, monitor, quote, amount, leverage);
            default -> throw new RuntimeException("信号动作不合法");
        }

        PersonalSignal sig = new PersonalSignal();
        sig.setMonitorId(monitorId);
        sig.setUserId(userId);
        sig.setAction(action);
        sig.setAmount(amount);
        sig.setRatioPct(ratioPct);
        sig.setLeverage(action.equals("open_short") ? (leverage == null ? 5 : leverage) : null);
        sig.setOkCount((Integer) dist.get("ok"));
        sig.setSkipCount((Integer) dist.get("skip"));
        String detail = String.join(" | ", (List<String>) dist.get("details"));
        sig.setDetail(detail.length() > 500 ? detail.substring(0, 500) : detail);
        signalMapper.insert(sig);

        Map<String, Object> resp = new HashMap<>();
        resp.put("signal", sig);
        resp.put("executed", dist.get("ok"));
        resp.put("skipped", dist.get("skip"));
        return resp;
    }

    /** 信号历史(分页, 默认 50 条) */
    public Map<String, Object> signals(String userId, Long monitorId, int limit, int offset) {
        Monitor monitor = monitorMapper.selectByIdAndUser(monitorId, userId);
        if (monitor == null) throw new RuntimeException("监控不存在");
        Map<String, Object> r = new HashMap<>();
        r.put("signals", signalMapper.selectByMonitorPaged(monitorId, limit, offset));
        r.put("total", signalMapper.countByMonitor(monitorId));
        return r;
    }

    /** 开空预检: 检查是否有冲突持仓 */
    public Map<String, Object> preCheckShort(String userId, Long monitorId) {
        Monitor monitor = monitorMapper.selectByIdAndUser(monitorId, userId);
        if (monitor == null) throw new RuntimeException("监控不存在");
        if (!"个人策略".equals(monitor.getStrategy())) throw new RuntimeException("仅个人策略支持开空");
        Map<String, Object> r = new HashMap<>();
        r.put("canShort", true);
        r.put("warning", "");
        // 检查现货多头
        Position longPos = positionMapper.selectOpen(userId, monitor.getSymbol(), "long");
        if (longPos != null && longPos.getAmount() > 0) {
            r.put("canShort", true);
            r.put("warning", "将先平掉现货多头 " + longPos.getAmount() + " " + monitor.getSymbol());
        }
        // 检查合约反向多头
        FuturesPosition exist = futuresPositionMapper.selectOpenBySymbol(userId, monitor.getSymbol());
        if (exist != null && "long".equals(exist.getDirection())) {
            r.put("canShort", false);
            r.put("warning", "合约已有反向多头持仓,请先在合约页平掉再开空");
        }
        return r;
    }

    /** follower 暂停/恢复自己的跟单 */
    public StrategyFollow setFollowStatus(String userId, Long followId, String status) {
        if (!"active".equals(status) && !"paused".equals(status)) {
            throw new RuntimeException("状态不合法(active/paused)");
        }
        if (followMapper.updateStatusByIdAndUser(followId, userId, status) == 0) {
            throw new RuntimeException("跟单不存在");
        }
        return followMapper.selectByIdAndUser(followId, userId);
    }

    public Map<String, Object> alerts(String userId, int limit, int offset) {
        Map<String, Object> r = new HashMap<>();
        r.put("alerts", alertMapper.selectByUserPaged(userId, limit, offset));
        r.put("total", alertMapper.countByUser(userId));
        r.put("unread", alertMapper.countUnread(userId));
        r.put("copy_paused", copyPaused());
        return r;
    }

    public void readAlerts(String userId) {
        alertMapper.markAllRead(userId);
    }

    /** 全局跟单风控开关(admin) */
    public boolean copyPaused() {
        return "1".equals(systemConfigMapper.get("copy_trading_paused"));
    }

    public void setCopyPaused(boolean paused) {
        String key = "copy_trading_paused";
        if (systemConfigMapper.update(key, paused ? "1" : "0") == 0) {
            systemConfigMapper.insert(key, paused ? "1" : "0");
        }
        if (paused) {
            Alert a = new Alert();
            a.setUserId("ALL");
            a.setType("risk");
            a.setTitle("全局跟单风控已暂停");
            a.setContent("管理员已暂停全部跟单信号分发,恢复前新信号不再执行");
            alertMapper.insert(a);
        }
    }

    public List<Alert> recentAlerts(int limit) {
        return alertMapper.selectRecent(limit);
    }

    // ══════════════ 动作实现 ══════════════

    private Map<String, Object> partialClose(String userId, Monitor m, Quote quote, int ratioPct) {
        Position longPos = positionMapper.selectOpen(userId, m.getSymbol(), "long");
        if (longPos != null) {
            double cap = "a-share".equals(quote.getMarket())
                    ? (longPos.getAvailableAmount() == null ? 0 : longPos.getAvailableAmount())
                    : longPos.getAmount();
            double sellQty = copyTradingService.floorByMarket(cap * ratioPct / 100.0, quote.getMarket());
            if (sellQty <= 0) throw new RuntimeException("可平数量过小(A股需整手)");
            Order filled = tradingService.placeOrder(userId, m.getSymbol(), "sell", "market",
                    null, sellQty, "个人策略");
            if (filled == null || filled.getFilledAmount() == null || filled.getFilledAmount() <= 0) {
                throw new RuntimeException("卖出未成交");
            }
            return copyTradingService.replicatePersonalSell(m, filled.getFilledAmount());
        }
        FuturesPosition fp = futuresPositionMapper.selectOpenBySymbol(userId, m.getSymbol());
        if (fp != null && "short".equals(fp.getDirection())) {
            double closeQty = fp.getAmount() * ratioPct / 100.0;
            futuresService.closePosition(userId, fp.getId(), closeQty);
            return copyTradingService.replicatePersonalCloseShort(m, closeQty);
        }
        throw new RuntimeException("当前无持仓可平");
    }

    private Map<String, Object> closeAll(String userId, Monitor m, Quote quote) {
        Position longPos = positionMapper.selectOpen(userId, m.getSymbol(), "long");
        FuturesPosition fp = futuresPositionMapper.selectOpenBySymbol(userId, m.getSymbol());
        boolean any = false;
        Map<String, Object> merged = new HashMap<>();
        merged.put("ok", 0);
        merged.put("skip", 0);
        merged.put("details", new java.util.ArrayList<String>());

        if (longPos != null) {
            double qty = "a-share".equals(quote.getMarket())
                    ? (longPos.getAvailableAmount() == null ? 0 : longPos.getAvailableAmount())
                    : longPos.getAmount();
            if (qty > 0) {
                tradingService.placeOrder(userId, m.getSymbol(), "sell", "market", null, qty, "个人策略");
                mergeDist(merged, copyTradingService.replicatePersonalSell(m, null));
                any = true;
            }
        }
        if (fp != null && "short".equals(fp.getDirection())) {
            futuresService.closePosition(userId, fp.getId(), fp.getAmount());
            mergeDist(merged, copyTradingService.replicatePersonalCloseShort(m, null));
            any = true;
        }
        if (!any) throw new RuntimeException("当前无持仓");
        return merged;
    }

    private Map<String, Object> openShort(String userId, Monitor m, Quote quote,
                                          Double amount, Integer leverage) {
        if (!"crypto".equals(quote.getMarket())) throw new RuntimeException("开空仅支持加密货币标的");
        int lev = leverage == null ? 5 : leverage;
        if (lev < 1 || lev > 125) throw new RuntimeException("杠杆需在 1-125 倍之间");
        if (amount == null || amount <= 0) throw new RuntimeException("开空数量必须大于 0");

        // 若有现货多头:先自动全平(个人策略同一时刻单方向持仓)
        Position longPos = positionMapper.selectOpen(userId, m.getSymbol(), "long");
        if (longPos != null) {
            double qty = "a-share".equals(quote.getMarket())
                    ? (longPos.getAvailableAmount() == null ? 0 : longPos.getAvailableAmount())
                    : longPos.getAmount();
            if (qty > 0) {
                tradingService.placeOrder(userId, m.getSymbol(), "sell", "market", null, qty, "个人策略");
                copyTradingService.replicatePersonalSell(m, null);
            }
        }
        // leader 合约已有反向多头 → 拒绝(避免误伤用户自发合约仓)
        FuturesPosition exist = futuresPositionMapper.selectOpenBySymbol(userId, m.getSymbol());
        if (exist != null && "long".equals(exist.getDirection())) {
            throw new RuntimeException("合约已有反向多头持仓,请先在合约页平掉再开空");
        }
        futuresService.openPosition(userId, m.getSymbol(), "short", lev, amount);
        return copyTradingService.replicatePersonalShort(m, amount, lev);
    }

    @SuppressWarnings("unchecked")
    private void mergeDist(Map<String, Object> merged, Map<String, Object> dist) {
        merged.put("ok", (Integer) merged.get("ok") + (Integer) dist.get("ok"));
        merged.put("skip", (Integer) merged.get("skip") + (Integer) dist.get("skip"));
        ((List<String>) merged.get("details")).addAll((List<String>) dist.get("details"));
    }

    private void checkGlobalNotPaused() {
        if (copyPaused()) throw new RuntimeException("全局跟单风控已暂停,恢复前信号不下发");
    }
}
