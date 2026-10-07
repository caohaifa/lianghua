package com.aiquant.service;

import com.aiquant.mapper.*;
import com.aiquant.model.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * 合约交易服务(USDT 本位永续合约模拟):
 * - 单向持仓:同标的只允许同向持仓,反向需先平仓
 * - 保证金:开仓保证金 = 名义价值 / 杠杆;钱包余额含占用保证金,可用 = 钱包 - 占用
 * - 盈亏:多头 (mark-entry)*qty;空头 (entry-mark)*qty;权益 = 钱包 + 未实现盈亏
 * - 强平:保证金 + 未实现盈亏 ≤ 维持保证金(名义*0.5%) → 按标记价市价全平
 * - 手续费:吃单 0.045%
 */
@Service
public class FuturesService {

    private static final Logger log = LoggerFactory.getLogger(FuturesService.class);

    public static final double FEE_RATE = 0.00045;
    public static final double MAINT_RATE = 0.005;

    @Autowired private FuturesAccountMapper accountMapper;
    @Autowired private FuturesPositionMapper positionMapper;
    @Autowired private FuturesOrderMapper orderMapper;
    @Autowired private AccountMapper spotAccountMapper;
    @Autowired private MarketService marketService;

    // ══════════════════════ 账户视图 ══════════════════════

    /** 合约账户总览(含强平检查) */
    public Map<String, Object> getAccountView(String userId) {
        FuturesAccount account = ensureAccount(userId);

        double usedMargin = 0, upnl = 0;
        int positionCount = 0;
        for (FuturesPosition p : positionMapper.selectOpenByUser(userId)) {
            Quote q = marketService.getQuote(p.getSymbol());
            if (q == null) continue;
            FuturesPosition live = checkLiquidation(p, q.getPrice());
            if (live == null) continue; // 已被强平
            usedMargin += live.getMargin();
            upnl += signedPnl(live, q.getPrice());
            positionCount++;
        }
        account = accountMapper.selectByUser(userId);
        double equity = account.getWalletBalance() + upnl;
        double available = account.getWalletBalance() - usedMargin;

        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("wallet_balance", round8(account.getWalletBalance()));
        vo.put("available", round8(available));
        vo.put("used_margin", round8(usedMargin));
        vo.put("unrealized_pnl", round8(upnl));
        vo.put("total_equity", round8(equity));
        vo.put("margin_ratio", equity > 0 ? round4(usedMargin / equity * 100) : 0);
        vo.put("position_count", positionCount);
        return vo;
    }

    /** 持仓列表(现价/未实现盈亏/收益率/预估强平价) */
    public List<Map<String, Object>> listPositions(String userId) {
        List<Map<String, Object>> list = new ArrayList<>();
        for (FuturesPosition p : positionMapper.selectOpenByUser(userId)) {
            Quote q = marketService.getQuote(p.getSymbol());
            if (q == null) continue;
            FuturesPosition live = checkLiquidation(p, q.getPrice());
            if (live == null) continue;
            list.add(toPositionVO(live, q.getPrice()));
        }
        return list;
    }

    private Map<String, Object> toPositionVO(FuturesPosition p, double mark) {
        double notional = mark * p.getAmount();
        double upnl = signedPnl(p, mark);
        double roe = upnl / p.getMargin() * 100;
        // 预估强平价:多 entry*(1-1/lev)/(1-维持率);空 entry*(1+1/lev)/(1+维持率)
        double liq = "long".equals(p.getDirection())
                ? p.getEntryPrice() * (1 - 1.0 / p.getLeverage()) / (1 - MAINT_RATE)
                : p.getEntryPrice() * (1 + 1.0 / p.getLeverage()) / (1 + MAINT_RATE);

        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("id", p.getId());
        vo.put("symbol", p.getSymbol());
        vo.put("direction", p.getDirection());
        vo.put("amount", round8(p.getAmount()));
        vo.put("entry_price", round8(p.getEntryPrice()));
        vo.put("mark_price", round8(mark));
        vo.put("leverage", p.getLeverage());
        vo.put("margin", round8(p.getMargin()));
        vo.put("notional", round8(notional));
        vo.put("unrealized_pnl", round8(upnl));
        vo.put("roe_pct", round4(roe));
        vo.put("liquidation_price", round8(liq));
        return vo;
    }

    // ══════════════════════ 开仓 ══════════════════════

    @Transactional
    public FuturesOrder openPosition(String userId, String symbol, String direction,
                                     int leverage, double amount) {
        if (symbol == null || marketService.getQuote(symbol) == null) {
            throw new RuntimeException("标的不存在或无行情");
        }
        Quote quote = marketService.getQuote(symbol);
        if (!"crypto".equals(quote.getMarket())) {
            throw new RuntimeException("合约暂仅支持加密货币标的");
        }
        if (!"long".equals(direction) && !"short".equals(direction)) {
            throw new RuntimeException("方向不合法(long/short)");
        }
        if (leverage < 1 || leverage > 125) throw new RuntimeException("杠杆需在 1-125 倍之间");
        if (amount <= 0) throw new RuntimeException("开仓数量必须大于 0");

        double mark = quote.getPrice();
        double notional = mark * amount;
        double fee = notional * FEE_RATE;
        double margin = notional / leverage;

        FuturesAccount account = ensureAccount(userId);
        double available = account.getWalletBalance() - sumUsedMargin(userId);
        if (margin + fee > available + 1e-9) {
            throw new RuntimeException("合约保证金不足(需约 " + String.format("%.2f", margin + fee)
                    + " USDT,可用 " + String.format("%.2f", available) + " USDT),可从资产页划转");
        }

        FuturesPosition existing = positionMapper.selectOpenBySymbol(userId, symbol);
        if (existing != null) {
            if (!existing.getDirection().equals(direction)) {
                throw new RuntimeException("已有反向持仓,请先平掉当前持仓再反向开仓");
            }
            double newAmount = existing.getAmount() + amount;
            double newEntry = (existing.getEntryPrice() * existing.getAmount() + notional) / newAmount;
            double newMargin = existing.getMargin() + margin;
            // 保持用户开仓时设定的杠杆,不重新计算(避免加仓导致杠杆漂移)
            existing.setAmount(newAmount);
            existing.setEntryPrice(newEntry);
            existing.setMargin(newMargin);
            positionMapper.updateHolding(existing);
        } else {
            FuturesPosition p = new FuturesPosition();
            p.setUserId(userId);
            p.setSymbol(symbol);
            p.setDirection(direction);
            p.setAmount(amount);
            p.setEntryPrice(mark);
            p.setLeverage(leverage);
            p.setMargin(margin);
            positionMapper.insert(p);
        }

        accountMapper.addWallet(userId, -fee);
        FuturesOrder order = buildOrder(userId, symbol, direction, "open", amount, mark,
                leverage, margin, fee, 0);
        orderMapper.insert(order);
        return order;
    }

    // ══════════════════════ 平仓 ══════════════════════

    @Transactional
    public FuturesOrder closePosition(String userId, Long positionId, Double closeAmount) {
        FuturesPosition p = positionMapper.selectById(positionId);
        if (p == null || !p.getUserId().equals(userId) || p.getStatus() != 0) {
            throw new RuntimeException("持仓不存在或已平仓");
        }
        double qty = closeAmount == null ? p.getAmount() : closeAmount;
        if (qty <= 0 || qty > p.getAmount() + 1e-9) {
            throw new RuntimeException("平仓数量不合法");
        }
        Quote quote = marketService.getQuote(p.getSymbol());
        double mark = quote != null ? quote.getPrice() : p.getEntryPrice();

        double pnl = signedPnl(p, mark, qty);
        double fee = mark * qty * FEE_RATE;
        double releasedMargin = p.getMargin() * qty / p.getAmount();

        double remain = p.getAmount() - qty;
        double remainMargin = p.getMargin() - releasedMargin;
        if (remain <= 1e-9) {
            FuturesPosition closed = new FuturesPosition();
            closed.setId(p.getId());
            closed.setAmount(0d);
            closed.setMargin(0d);
            positionMapper.close(closed);
        } else {
            p.setAmount(remain);
            p.setMargin(remainMargin);
            positionMapper.updateHolding(p);
        }

        FuturesAccount account = ensureAccount(userId);
        accountMapper.addWallet(userId, pnl - fee);
        FuturesOrder order = buildOrder(userId, p.getSymbol(), p.getDirection(), "close", qty, mark,
                p.getLeverage(), releasedMargin, fee, pnl);
        orderMapper.insert(order);
        return order;
    }

    // ══════════════════════ 划转 ══════════════════════

    /** 现货 USDT 钱包 ↔ 合约钱包。direction=in 现货→合约 / out 合约→现货 */
    @Transactional
    public Map<String, Object> transfer(String userId, String direction, double amount) {
        if (amount <= 0) throw new RuntimeException("划转金额必须大于 0");
        if (!"in".equals(direction) && !"out".equals(direction)) {
            throw new RuntimeException("划转方向不合法(in/out)");
        }
        FuturesAccount futures = ensureAccount(userId);
        if ("in".equals(direction)) {
            Account spot = spotAccountMapper.selectByUserAndCurrency(userId, "USDT");
            double spotBal = spot != null ? spot.getBalance() : 0;
            if (amount > spotBal + 1e-9) {
                throw new RuntimeException("现货 USDT 可用余额不足");
            }
            spotAccountMapper.addBalance(userId, "USDT", -amount);
            accountMapper.addWallet(userId, amount);
        } else {
            double available = futures.getWalletBalance() - sumUsedMargin(userId);
            if (amount > available + 1e-9) {
                throw new RuntimeException("合约可划转余额不足(占用保证金不可划转)");
            }
            accountMapper.addWallet(userId, -amount);
            // 现货 USDT 账户缺失则懒初始化;init 后复查,失败抛异常回滚避免资金丢失
            Account spot = spotAccountMapper.selectByUserAndCurrency(userId, "USDT");
            if (spot == null) {
                spotAccountMapper.initUsdt(userId);
                spot = spotAccountMapper.selectByUserAndCurrency(userId, "USDT");
            }
            if (spot == null) {
                throw new RuntimeException("现货 USDT 账户初始化失败");
            }
            spotAccountMapper.addBalance(userId, "USDT", amount);
        }
        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("direction", direction);
        vo.put("amount", round8(amount));
        vo.put("status", "ok");
        return vo;
    }

    // ══════════════════════ 强平 ══════════════════════

    /**
     * 检查单笔持仓是否触发强平:保证金 + 未实现盈亏 ≤ 名义*维持率。
     * 触发则按标记价全平,返回 null;否则返回(可能为最新的)持仓。
     */
    @Transactional
    public FuturesPosition checkLiquidation(FuturesPosition p, double mark) {
        double upnl = signedPnl(p, mark);
        double maint = mark * p.getAmount() * MAINT_RATE;
        if (p.getMargin() + upnl <= maint) {
            // CAS 原子强平: 仅 status=0 时成功,防止并发重复扣款
            if (positionMapper.casLiquidate(p.getId()) == 0) {
                return null; // 已被其他线程强平
            }
            double fee = mark * p.getAmount() * FEE_RATE; // 强平手续费
            ensureAccount(p.getUserId());
            accountMapper.addWallet(p.getUserId(), upnl - fee);
            FuturesOrder order = buildOrder(p.getUserId(), p.getSymbol(), p.getDirection(),
                    "close", p.getAmount(), mark, p.getLeverage(), 0, fee, upnl);
            orderMapper.insert(order);
            log.warn("[强平] user={} {} {}x amount={} mark={} 亏损={} 手续费={}",
                    p.getUserId(), p.getSymbol(), p.getDirection(), p.getAmount(), mark, upnl, fee);
            return null;
        }
        return p;
    }

    /** 定时全量强平扫描(5s 一次) */
    @Scheduled(fixedRate = 5000, initialDelay = 4000)
    public void liquidationSweep() {
        for (FuturesPosition p : positionMapper.selectAllOpen()) {
            Quote q = marketService.getQuote(p.getSymbol());
            if (q == null) continue;
            try {
                checkLiquidation(p, q.getPrice());
            } catch (Exception e) {
                log.warn("强平检查失败 posId={}: {}", p.getId(), e.getMessage());
            }
        }
    }

    // ══════════════════════ 查询 ══════════════════════

    public List<FuturesOrder> listOrders(String userId, int limit) {
        return orderMapper.selectByUser(userId, Math.max(1, Math.min(limit, 200)));
    }

    // ══════════════════════ 内部工具 ══════════════════════

    private FuturesAccount ensureAccount(String userId) {
        FuturesAccount account = accountMapper.selectByUser(userId);
        if (account == null) {
            accountMapper.initAccount(userId);
            account = accountMapper.selectByUser(userId);
        }
        return account;
    }

    private double sumUsedMargin(String userId) {
        double sum = 0;
        for (FuturesPosition p : positionMapper.selectOpenByUser(userId)) {
            sum += p.getMargin();
        }
        return sum;
    }

    private double signedPnl(FuturesPosition p, double mark) {
        return signedPnl(p, mark, p.getAmount());
    }

    private double signedPnl(FuturesPosition p, double mark, double qty) {
        return "long".equals(p.getDirection())
                ? (mark - p.getEntryPrice()) * qty
                : (p.getEntryPrice() - mark) * qty;
    }

    private FuturesOrder buildOrder(String userId, String symbol, String direction, String action,
                                    double amount, double price, int leverage, double margin,
                                    double fee, double pnl) {
        FuturesOrder o = new FuturesOrder();
        o.setUserId(userId);
        o.setOrderId(UUID.randomUUID().toString().replace("-", "").substring(0, 24));
        o.setSymbol(symbol);
        o.setDirection(direction);
        o.setAction(action);
        o.setAmount(amount);
        o.setPrice(price);
        o.setLeverage(leverage);
        o.setMargin(margin);
        o.setFee(fee);
        o.setPnl(pnl);
        return o;
    }

    private double round8(double v) { return Math.round(v * 1e8) / 1e8; }
    private double round4(double v) { return Math.round(v * 1e4) / 1e4; }
}
