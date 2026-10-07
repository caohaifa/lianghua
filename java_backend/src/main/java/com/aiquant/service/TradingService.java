package com.aiquant.service;

import com.aiquant.mapper.*;
import com.aiquant.model.*;
import com.aiquant.service.exchange.BinanceExchangeChannel;
import com.aiquant.service.exchange.ExchangeChannel;
import com.aiquant.service.exchange.SimulatedExchangeChannel;
import com.aiquant.util.AesUtil;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * 交易服务:下单(风控前置) / 撤单 / 持仓 / 账户总览 / 交易模式切换。
 *
 * 现货币语: buy=开/加多仓, sell=平/减多仓(无持仓不可卖)。
 * 通道路由: trading_mode=live 且有启用中的交易所凭据 → Binance 通道,
 *           否则(含 live 但凭据被删)降级模拟通道。
 */
@Service
public class TradingService {

    @Autowired private OrderMapper orderMapper;
    @Autowired private PositionMapper positionMapper;
    @Autowired private AccountMapper accountMapper;
    @Autowired private UserMapper userMapper;
    @Autowired private BrokerAccountMapper brokerAccountMapper;
    @Autowired private MarketService marketService;
    @Autowired private RiskEngine riskEngine;
    @Autowired private SimulatedExchangeChannel simulatedChannel;
    @Autowired private BinanceExchangeChannel binanceChannel;
    @Autowired private AesUtil aesUtil;
    @Autowired private MeterRegistry meterRegistry;
    @Autowired private ReferralService referralService;

    // ══════════════════════ 账户 ══════════════════════

    /** 账户总览(默认 USDT 主钱包):总资产 = 可用余额 + 同币种持仓市值 */
    public Map<String, Object> getAccountOverview(String userId) {
        return getAccountOverview(userId, "USDT");
    }

    /** 指定币种账户总览:仅汇总该币种计价的持仓(USDT 与 CNY 不混算) */
    public Map<String, Object> getAccountOverview(String userId, String currency) {
        currency = normalizeCurrency(currency);
        Account account = ensureAccount(userId, currency);
        List<Position> positions = refreshPositions(userId);

        double positionValue = 0, totalPnl = 0;
        int positionCount = 0;
        for (Position p : positions) {
            Quote q = marketService.getQuote(p.getSymbol());
            if (q == null || !currency.equals(q.getCurrency())) continue;
            positionValue += p.getAmount() * p.getCurrentPrice();
            totalPnl += p.getPnl();
            positionCount++;
        }
        double totalAsset = account.getBalance() + positionValue;
        double costBasis = Math.max(totalAsset - totalPnl, 1e-9);

        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("currency", account.getCurrency());
        vo.put("total_asset", round8(totalAsset));
        vo.put("available", round8(account.getBalance()));
        vo.put("position_value", round8(positionValue));
        vo.put("total_pnl", round8(totalPnl));
        vo.put("total_pnl_pct", round4(totalPnl / costBasis * 100));
        vo.put("position_count", positionCount);
        return vo;
    }

    /** 取指定币种账户,缺失则懒初始化(USDT 10 万 / CNY 100 万) */
    private Account ensureAccount(String userId, String currency) {
        currency = normalizeCurrency(currency);
        Account account = accountMapper.selectByUserAndCurrency(userId, currency);
        if (account == null) {
            if ("CNY".equals(currency)) accountMapper.initCny(userId);
            else accountMapper.initUsdt(userId);
            account = accountMapper.selectByUserAndCurrency(userId, currency);
        }
        return account;
    }

    private String normalizeCurrency(String currency) {
        return "CNY".equalsIgnoreCase(currency) ? "CNY" : "USDT";
    }

    // ══════════════════════ 下单 ══════════════════════

    /**
     * 下单入口 + 埋点:aiquant_orders_total{result} 供 Prometheus 计算下单成功率
     * (attempt=受理尝试, filled/pending=接受, rejected=校验/风控/资金拒绝)
     */
    @Transactional
    public Order placeOrder(String userId, String symbol, String side, String orderType,
                            Double price, Double amount, String strategyName) {
        meterRegistry.counter("aiquant_orders_total", "result", "attempt").increment();
        try {
            Order order = doPlaceOrder(userId, symbol, side, orderType, price, amount, strategyName);
            meterRegistry.counter("aiquant_orders_total", "result", order.getStatus()).increment();
            return order;
        } catch (RuntimeException e) {
            meterRegistry.counter("aiquant_orders_total", "result", "rejected").increment();
            throw e;
        }
    }

    private Order doPlaceOrder(String userId, String symbol, String side, String orderType,
                               Double price, Double amount, String strategyName) {
        // 1. 参数校验
        if (symbol == null || symbol.isBlank()) throw new RuntimeException("标的不能为空");
        if (!"buy".equals(side) && !"sell".equals(side)) throw new RuntimeException("买卖方向不合法");
        if (!"market".equals(orderType) && !"limit".equals(orderType)) throw new RuntimeException("订单类型不合法");
        if (amount == null || amount <= 0) throw new RuntimeException("数量必须大于 0");
        if ("limit".equals(orderType) && (price == null || price <= 0)) throw new RuntimeException("限价单必须填写价格");
        Quote quote = marketService.getQuote(symbol);
        if (quote == null) throw new RuntimeException("标的 " + symbol + " 无行情,不可交易");
        String currency = normalizeCurrency(quote.getCurrency());
        boolean aShare = "a-share".equals(quote.getMarket());

        // A股:按手(1手=100股)下单,数量须为 100 的整数倍;加密可小数
        if (aShare && !isRoundLots(amount)) {
            throw new RuntimeException("A股需按手下单(1手=100股),数量须为100的整数倍");
        }

        // 2. 持仓语义校验 + 风控前置
        Position open = positionMapper.selectOpen(userId, symbol, "long");
        if ("sell".equals(side)) {
            if (open == null) throw new RuntimeException("当前无 " + symbol + " 持仓,不可卖出");
            if (amount > open.getAmount() + 1e-9) throw new RuntimeException("卖出数量超过持仓数量");
            // A股 T+1:当日买入的冻结份额次日才可卖
            if (aShare) {
                double sellable = open.getAvailableAmount() == null ? 0 : open.getAvailableAmount();
                if (amount > sellable + 1e-9) {
                    throw new RuntimeException("A股为T+1交易,当日买入份额需下一交易日才可卖出");
                }
            }
        }
        RiskEngine.OrderRequest riskReq = new RiskEngine.OrderRequest();
        riskReq.setUserId(userId);
        riskReq.setSymbol(symbol);
        riskReq.setLong(true);
        riskReq.setNewPosition("buy".equals(side) && open == null);
        riskReq.setAmount(amount);
        riskReq.setEntryPrice("limit".equals(orderType) ? price : quote.getPrice());
        riskReq.setStopLossPrice(0);
        String rejectReason = riskEngine.checkOrder(riskReq);
        if (rejectReason != null) throw new RuntimeException("风控拦截: " + rejectReason);

        // 3. 资金校验(buy 需足够对应币种余额;按限价/现价预估)
        Account account = ensureAccount(userId, currency);
        double estimatedCost = amount * ("limit".equals(orderType) ? price : quote.getPrice());
        if ("buy".equals(side) && estimatedCost > account.getBalance() + 1e-9) {
            throw new RuntimeException("可用余额不足(需约 " + String.format("%.2f", estimatedCost) + " " + currency + ")");
        }

        // 4. 通道路由并下单
        ExchangeChannel.ChannelOrderRequest channelReq = new ExchangeChannel.ChannelOrderRequest();
        channelReq.setSymbol(symbol);
        channelReq.setSide(side);
        channelReq.setOrderType(orderType);
        channelReq.setPrice(price);
        channelReq.setAmount(amount);

        User user = userMapper.selectByUserId(userId);
        BrokerAccount credential = "live".equals(user.getTradingMode())
                ? brokerAccountMapper.selectActive(userId) : null;
        ExchangeChannel.FillResult fill;
        String channelName;
        if (credential != null && "binance".equals(credential.getExchange())) {
            fill = binanceChannel.placeOrder(channelReq,
                    new BinanceExchangeChannel.Credential(credential.getApiKey(),
                            aesUtil.decrypt(credential.getSecretKey())));
            channelName = "binance";
        } else {
            // sim 模式,或 live 模式但凭据不可用(非 binance 交易所暂走模拟撮合)
            fill = simulatedChannel.placeOrder(channelReq);
            channelName = credential != null ? credential.getExchange() + "(模拟撮合)" : "sim";
        }

        // 5. 落订单
        Order order = new Order();
        order.setUserId(userId);
        order.setOrderId(UUID.randomUUID().toString().replace("-", ""));
        order.setSymbol(symbol);
        order.setSide(side);
        order.setOrderType(orderType);
        order.setAmount(amount);
        order.setFilledAmount(fill.getFillAmount());
        order.setPrice(fill.isFilled() ? fill.getFillPrice() : price);
        order.setStatus(fill.isFilled() ? "filled" : "pending");
        order.setStrategyName(strategyName);
        order.setChannel(channelName);
        orderMapper.insert(order);

        // 6. 成交后更新资金与持仓
        if (fill.isFilled()) {
            applyFill(order.getOrderId(), userId, symbol, side, fill.getFillPrice(),
                    fill.getFillAmount(), open, strategyName, currency, aShare);
        }
        return orderMapper.selectByOrderId(order.getOrderId());
    }

    /** 成交入账:资金 + 持仓加权 + A股 T+1 可卖份额 + 平仓盈亏记风控 + 邀请奖励返佣 */
    private void applyFill(String orderId, String userId, String symbol, String side,
                           double fillPrice, double fillAmount, Position open,
                           String strategyName, String currency, boolean aShare) {
        double notional = fillPrice * fillAmount;
        if ("buy".equals(side)) {
            accountMapper.addBalance(userId, currency, -notional);
            if (open == null) {
                Position p = new Position();
                p.setUserId(userId);
                p.setSymbol(symbol);
                p.setSide("long");
                p.setAmount(fillAmount);
                // A股当日买入冻结(available=0)次日解冻;加密即时可卖
                p.setAvailableAmount(aShare ? 0d : fillAmount);
                p.setEntryPrice(fillPrice);
                p.setCurrentPrice(fillPrice);
                p.setStrategyName(strategyName);
                positionMapper.insert(p);
            } else {
                double newAmount = open.getAmount() + fillAmount;
                double newEntry = (open.getEntryPrice() * open.getAmount() + notional) / newAmount;
                double oldAvailable = open.getAvailableAmount() == null ? 0 : open.getAvailableAmount();
                open.setAmount(newAmount);
                // A股当日加仓份额冻结,可卖维持原值;加密全部可卖
                open.setAvailableAmount(aShare ? oldAvailable : newAmount);
                open.setEntryPrice(newEntry);
                open.setCurrentPrice(fillPrice);
                open.setPnl((fillPrice - newEntry) * newAmount);
                open.setPnlPct((fillPrice - newEntry) / newEntry * 100);
                positionMapper.updateHolding(open);
            }
        } else {
            // sell:减仓/平仓,已实现盈亏入账,同步扣减可卖份额
            accountMapper.addBalance(userId, currency, notional);
            double realizedPnl = (fillPrice - open.getEntryPrice()) * fillAmount;
            double remain = open.getAmount() - fillAmount;
            double oldAvailable = open.getAvailableAmount() == null ? 0 : open.getAvailableAmount();
            double remainAvailable = Math.max(oldAvailable - fillAmount, 0);
            if (remain <= 1e-9) {
                open.setCurrentPrice(fillPrice);
                open.setPnl(realizedPnl); // 本次已实现
                open.setPnlPct((fillPrice - open.getEntryPrice()) / open.getEntryPrice() * 100);
                positionMapper.close(open);
            } else {
                open.setAmount(remain);
                open.setAvailableAmount(remainAvailable);
                open.setCurrentPrice(fillPrice);
                open.setPnl((fillPrice - open.getEntryPrice()) * remain);
                open.setPnlPct((fillPrice - open.getEntryPrice()) / open.getEntryPrice() * 100);
                positionMapper.updateHolding(open);
            }
            if (realizedPnl < 0) {
                // 日亏损熔断统计:亏损占该笔名义本金比例
                riskEngine.recordPnl(userId, -realizedPnl / (open.getEntryPrice() * fillAmount));
            }
        }

        // 邀请奖励:被推荐人成交后,推荐人获交易流水 1% 返佣(USDT/CNY 随交易币种)
        referralService.payReward(userId, orderId, symbol, currency, notional);
    }

    // ══════════════════════ 限价单撮合(由 LimitOrderMatcher 定时驱动) ══════════════════════

    /**
     * 尝试撮合一笔挂单中的限价单:价格触达则按限价成交入账。
     * 买单:现价 ≤ 限价 成交;卖单:现价 ≥ 限价 成交。
     * 挂单期间持仓/资金可能已变化:卖出无持仓或数量不足 → 自动撤单;买入余额不足 → 保留挂单等待。
     *
     * @return true=本次已成交
     */
    @Transactional
    public boolean fillPendingOrder(Order order, double currentPrice) {
        boolean triggered = "buy".equals(order.getSide())
                ? currentPrice <= order.getPrice()
                : currentPrice >= order.getPrice();
        if (!triggered) return false;

        Quote quote = marketService.getQuote(order.getSymbol());
        if (quote == null) return false;
        String currency = normalizeCurrency(quote.getCurrency());
        boolean aShare = "a-share".equals(quote.getMarket());

        Position open = positionMapper.selectOpen(order.getUserId(), order.getSymbol(), "long");
        if ("sell".equals(order.getSide())) {
            if (open == null || order.getAmount() > open.getAmount() + 1e-9) {
                // 挂单期间持仓已被手动平掉/减仓 → 撤单
                orderMapper.cancelPending(order.getOrderId());
                return false;
            }
            if (aShare) {
                double sellable = open.getAvailableAmount() == null ? 0 : open.getAvailableAmount();
                if (order.getAmount() > sellable + 1e-9) {
                    // T+1 冻结中,保留挂单待次日解冻后再撮合(不撤单)
                    return false;
                }
            }
        } else {
            Account account = ensureAccount(order.getUserId(), currency);
            if (order.getPrice() * order.getAmount() > account.getBalance() + 1e-9) {
                return false; // 对应币种余额不足,保留挂单
            }
        }

        double fillPrice = order.getPrice(); // 限价单按限价成交
        order.setStatus("filled");
        order.setFilledAmount(order.getAmount());
        order.setPrice(fillPrice);
        orderMapper.updateFill(order);
        applyFill(order.getOrderId(), order.getUserId(), order.getSymbol(), order.getSide(),
                fillPrice, order.getAmount(), open, order.getStrategyName(), currency, aShare);
        return true;
    }

    // ══════════════════════ 撤单 / 查询 ══════════════════════

    public void cancelOrder(String userId, String orderId) {
        Order order = orderMapper.selectByOrderId(orderId);
        if (order == null || !order.getUserId().equals(userId)) throw new RuntimeException("订单不存在");
        if (!"pending".equals(order.getStatus())) throw new RuntimeException("仅挂单中的限价单可撤销");
        if (orderMapper.cancelPending(orderId) == 0) throw new RuntimeException("订单状态已变化,请刷新");
    }

    public List<Order> listOrders(String userId, String symbol, int limit) {
        if (symbol != null && !symbol.isEmpty()) {
            return orderMapper.selectByUserAndSymbol(userId, symbol, Math.min(Math.max(limit, 1), 200));
        }
        return orderMapper.selectByUser(userId, Math.min(Math.max(limit, 1), 200));
    }

    /** 持仓列表(用最新行情计算现价/浮动盈亏,只读不写库;由定时任务统一持久化) */
    public List<Position> refreshPositions(String userId) {
        List<Position> positions = positionMapper.selectOpenByUser(userId);
        for (Position p : positions) {
            Quote q = marketService.getQuote(p.getSymbol());
            if (q == null) continue;
            double current = q.getPrice();
            double pnl = (current - p.getEntryPrice()) * p.getAmount();
            p.setCurrentPrice(current);
            p.setPnl(round8(pnl));
            p.setPnlPct(round4((current - p.getEntryPrice()) / p.getEntryPrice() * 100));
        }
        return positions;
    }

    // ══════════════════════ 交易模式 ══════════════════════

    /** 切换模拟/实盘;实盘前置:已签协议 + 已绑定启用中的 API Key */
    public Map<String, Object> switchMode(String userId, String mode) {
        if (!"sim".equals(mode) && !"live".equals(mode)) throw new RuntimeException("交易模式不合法");
        User user = userMapper.selectByUserId(userId);
        if ("live".equals(mode)) {
            if (!Boolean.TRUE.equals(user.getAgreementSigned())) {
                throw new RuntimeException("请先完成协议签署,再开启实盘");
            }
            if (brokerAccountMapper.selectActive(userId) == null) {
                throw new RuntimeException("请先在「API Key 管理」绑定交易所,再开启实盘");
            }
        }
        userMapper.updateTradingMode(userId, mode);
        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("trading_mode", mode);
        return vo;
    }

    public Map<String, Object> getMode(String userId) {
        User user = userMapper.selectByUserId(userId);
        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("trading_mode", user.getTradingMode() == null ? "sim" : user.getTradingMode());
        vo.put("has_api_key", brokerAccountMapper.selectActive(userId) != null);
        vo.put("agreement_signed", Boolean.TRUE.equals(user.getAgreementSigned()));
        return vo;
    }

    /**
     * A股 T+1 解冻:工作日 09:20 把昨日及之前买入的冻结份额转为可卖
     * (Spring cron: 秒 分 时 日 月 周,周域 1=周一 … 5=周五)
     */
    @Scheduled(cron = "0 20 9 * * 1-5")
    public void releaseAshareFrozen() {
        int n = positionMapper.releaseAshare();
        if (n > 0) System.out.println("[T+1] A股冻结份额解冻,持仓数=" + n);
    }

    /** A股整手判定:数量须为正整数且为 100 的整数倍 */
    private boolean isRoundLots(double amount) {
        if (amount <= 0 || Math.abs(amount - Math.rint(amount)) > 1e-6) return false;
        return ((long) Math.rint(amount)) % 100 == 0;
    }

    private double round8(double v) { return Math.round(v * 1e8) / 1e8; }
    private double round4(double v) { return Math.round(v * 1e4) / 1e4; }
}
