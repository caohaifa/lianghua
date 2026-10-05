package com.aiquant.service;

import com.aiquant.model.Quote;
import com.aiquant.service.market.RealMarketDataProvider;
import com.aiquant.ws.MarketWebSocketHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 行情数据服务
 * 1. 启动时以种子数据作为"最后已知值"占位(避免冷启动空表)
 * 2. 定时从真实行情源(币安公共数据 + 新浪财经)拉取快照刷新缓存
 * 3. 拉取失败则保留上一次数据并等待下次重试,不造假
 * 4. 每 2 秒把当前缓存通过 WebSocket 广播(不再随机漂移)
 */
@Service
public class MarketService {

    private static final Logger log = LoggerFactory.getLogger(MarketService.class);

    @Autowired
    private MarketWebSocketHandler wsHandler;

    @Autowired
    private RealMarketDataProvider realProvider;

    // 行情缓存: symbol -> Quote
    private final Map<String, Quote> quoteCache = new ConcurrentHashMap<>();

    // 已拿到真实数据的 symbol(只广播真实标的,冷启动占位数据不外推)
    private final Set<String> realSymbols = ConcurrentHashMap.newKeySet();

    // K 线缓存: symbol|period|limit -> {bars, fetchedAt}
    private final Map<String, KlineCache> klineCache = new ConcurrentHashMap<>();

    private static final long KLINE_TTL_MS = 15_000;

    // 初始种子数据:仅用于冷启动占位,真实数据到达后即被覆盖
    // 每行: symbol, name, price, changePct, volume, quoteUnit, market
    public MarketService() {
        Object[][] data = {
                // —— 加密货币(USDT 本位)——
                {"BTC/USDT", "比特币", 65432.50, 2.34, 1.25e9, "USDT", "crypto"},
                {"ETH/USDT", "以太坊", 3218.80, -1.12, 8.2e8, "USDT", "crypto"},
                {"SOL/USDT", "Solana", 156.32, 5.67, 3.1e8, "USDT", "crypto"},
                {"BNB/USDT", "币安币", 612.40, 1.85, 2.4e8, "USDT", "crypto"},
                {"XRP/USDT", "瑞波币", 0.623, 3.42, 4.6e8, "USDT", "crypto"},
                {"DOGE/USDT", "狗狗币", 0.1685, -2.75, 3.8e8, "USDT", "crypto"},
                {"ADA/USDT", "艾达币", 0.452, 2.10, 1.7e8, "USDT", "crypto"},
                {"AVAX/USDT", "雪崩", 28.65, 4.32, 1.5e8, "USDT", "crypto"},
                {"DOT/USDT", "波卡", 6.85, -0.86, 1.2e8, "USDT", "crypto"},
                {"LINK/USDT", "链环", 14.32, 2.98, 1.4e8, "USDT", "crypto"},
                {"TRX/USDT", "波场", 0.1285, 1.45, 9.5e7, "USDT", "crypto"},
                {"LTC/USDT", "莱特币", 84.50, -1.24, 8.8e7, "USDT", "crypto"},
                {"TON/USDT", "Toncoin", 5.42, 3.67, 1.1e8, "USDT", "crypto"},
                {"ATOM/USDT", "宇宙", 7.25, 1.12, 6.4e7, "USDT", "crypto"},
                {"NEAR/USDT", "NEAR Protocol", 5.85, -2.05, 7.2e7, "USDT", "crypto"},
                {"SHIB/USDT", "柴犬币", 0.0000215, 4.56, 5.2e8, "USDT", "crypto"},
                {"UNI/USDT", "Uniswap", 12.50, 1.85, 9.6e7, "USDT", "crypto"},
                {"XLM/USDT", "恒星币", 0.385, -0.92, 1.8e8, "USDT", "crypto"},
                {"FIL/USDT", "Filecoin", 4.62, 2.44, 1.1e8, "USDT", "crypto"},
                {"APT/USDT", "Aptos", 8.25, 3.18, 1.4e8, "USDT", "crypto"},
                {"ARB/USDT", "Arbitrum", 0.955, -1.65, 2.2e8, "USDT", "crypto"},
                {"OP/USDT", "Optimism", 1.78, 0.78, 1.3e8, "USDT", "crypto"},
                {"INJ/USDT", "Injective", 24.60, 5.22, 8.5e7, "USDT", "crypto"},
                {"SUI/USDT", "Sui", 3.62, 2.96, 4.8e8, "USDT", "crypto"},
                {"PEPE/USDT", "佩佩蛙", 0.0000105, -3.45, 6.5e8, "USDT", "crypto"},
                {"AAVE/USDT", "Aave", 268.50, 1.36, 1.6e8, "USDT", "crypto"},
                {"ALGO/USDT", "Algorand", 0.245, -0.58, 7.8e7, "USDT", "crypto"},
                {"FTM/USDT", "Fantom", 0.725, 2.15, 1.2e8, "USDT", "crypto"},
                {"EOS/USDT", "柚子币", 0.825, -1.32, 9.2e7, "USDT", "crypto"},
                {"GRT/USDT", "The Graph", 0.265, 1.68, 6.2e7, "USDT", "crypto"},
                // —— A股:指数 + 热门个股 ——
                {"000001", "上证指数", 3128.42, 0.89, 2.34e11, "CNY", "a-share"},
                {"000300", "沪深300", 3675.21, -0.34, 1.85e11, "CNY", "a-share"},
                {"399001", "深证成指", 10245.60, 1.12, 2.68e11, "CNY", "a-share"},
                {"399006", "创业板指", 2015.80, -0.58, 1.26e11, "CNY", "a-share"},
                {"000688", "科创50", 745.30, 1.46, 4.5e10, "CNY", "a-share"},
                {"600519", "贵州茅台", 1685.00, 0.76, 5.5e9, "CNY", "a-share"},
                {"300750", "宁德时代", 245.60, 2.34, 4.2e9, "CNY", "a-share"},
                {"002594", "比亚迪", 268.40, -1.08, 3.1e9, "CNY", "a-share"},
                {"601318", "中国平安", 52.30, 0.62, 2.8e9, "CNY", "a-share"},
                {"600036", "招商银行", 38.65, 0.95, 2.2e9, "CNY", "a-share"},
                {"000858", "五粮液", 132.50, -0.44, 1.9e9, "CNY", "a-share"},
                {"601012", "隆基绿能", 18.40, 3.12, 2.5e9, "CNY", "a-share"},
                {"300059", "东方财富", 15.85, 1.88, 6.8e9, "CNY", "a-share"},
                {"688981", "中芯国际", 88.60, 2.56, 3.4e9, "CNY", "a-share"},
                {"000333", "美的集团", 68.20, -0.72, 1.7e9, "CNY", "a-share"},
                {"000016", "上证50", 2650.30, 0.52, 9.8e10, "CNY", "a-share"},
                {"000905", "中证500", 5620.45, -0.28, 1.1e11, "CNY", "a-share"},
                {"600030", "中信证券", 27.85, 1.12, 2.6e9, "CNY", "a-share"},
                {"600276", "恒瑞医药", 45.20, -0.85, 1.5e9, "CNY", "a-share"},
                {"600887", "伊利股份", 27.40, 0.66, 1.2e9, "CNY", "a-share"},
                {"601888", "中国中免", 92.60, -1.24, 1.8e9, "CNY", "a-share"},
                {"600900", "长江电力", 27.15, 0.42, 1.4e9, "CNY", "a-share"},
                {"601899", "紫金矿业", 17.85, 2.15, 2.9e9, "CNY", "a-share"},
                {"002415", "海康威视", 30.45, -0.96, 1.6e9, "CNY", "a-share"},
                {"000063", "中兴通讯", 34.20, 1.48, 2.4e9, "CNY", "a-share"},
                {"002475", "立讯精密", 38.60, 0.88, 2.1e9, "CNY", "a-share"},
                {"601088", "中国神华", 38.25, -0.35, 1.3e9, "CNY", "a-share"},
                {"600028", "中国石化", 6.42, 0.18, 9.5e8, "CNY", "a-share"},
                {"601668", "中国建筑", 5.65, 0.55, 1.1e9, "CNY", "a-share"},
                {"603288", "海天味业", 42.30, -0.62, 8.2e8, "CNY", "a-share"},
        };
        long now = System.currentTimeMillis();
        for (Object[] row : data) {
            quoteCache.put((String) row[0],
                    Quote.of((String) row[0], (String) row[1],
                            ((Number) row[2]).doubleValue(), ((Number) row[3]).doubleValue(),
                            ((Number) row[4]).doubleValue(), (String) row[5], (String) row[6], now));
        }
    }

    /**
     * 获取行情快照列表
     */
    public List<Quote> getQuotes() {
        return new ArrayList<>(quoteCache.values());
    }

    /**
     * 获取单个标的行情
     */
    public Quote getQuote(String symbol) {
        return quoteCache.get(symbol);
    }

    // ───────────────────────── 真实快照拉取 ─────────────────────────

    /** 加密货币:每 5 秒批量刷新 */
    @Scheduled(fixedRate = 5000, initialDelay = 1500)
    public void refreshCrypto() {
        try {
            Map<String, Map<String, Object>> data = realProvider.fetchCryptoQuotes();
            data.forEach(this::mergeCrypto);
        } catch (Exception e) {
            log.warn("加密行情拉取失败,保留上次数据: {}", e.getMessage());
        }
    }

    /** A 股:每 10 秒刷新 */
    @Scheduled(fixedRate = 10_000, initialDelay = 2500)
    public void refreshAShare() {
        try {
            Map<String, Map<String, Object>> data = realProvider.fetchAShareQuotes();
            data.forEach(this::mergeAShare);
        } catch (Exception e) {
            log.warn("A股行情拉取失败,保留上次数据: {}", e.getMessage());
        }
    }

    private void mergeCrypto(String symbol, Map<String, Object> d) {
        Quote old = quoteCache.get(symbol);
        String name = old != null ? old.getName() : symbol;
        quoteCache.put(symbol, Quote.of(symbol, name,
                num(d.get("price")), num(d.get("change")), num(d.get("volume")),
                "USDT", "crypto", lng(d.get("timestamp"))));
        realSymbols.add(symbol);
    }

    private void mergeAShare(String symbol, Map<String, Object> d) {
        Quote old = quoteCache.get(symbol);
        Object nm = d.get("name");
        String name = nm != null ? nm.toString() : (old != null ? old.getName() : symbol);
        quoteCache.put(symbol, Quote.of(symbol, name,
                num(d.get("price")), num(d.get("change")), num(d.get("volume")),
                "CNY", "a-share", lng(d.get("timestamp"))));
        realSymbols.add(symbol);
    }

    /**
     * 立即拉取真实行情(手动刷新)
     */
    public void refreshNow() {
        refreshCrypto();
        refreshAShare();
    }

    // ───────────────────────── 真实 K 线 ─────────────────────────

    private static final Set<String> VALID_PERIOD = Set.of("1m", "5m", "1h", "1d");

    /**
     * 获取 K 线(OHLCV)。优先真实源并短期缓存;拉取失败时返回上次缓存。
     *
     * @param symbol 标的(支持带斜杠,如 BTC/USDT,走 query 参数传入)
     * @param period 1m / 5m / 1h / 1d
     * @param limit  根数(1-500)
     */
    public List<Map<String, Object>> getKline(String symbol, String period, int limit) {
        Quote quote = quoteCache.get(symbol);
        if (quote == null) return null;
        if (!VALID_PERIOD.contains(period)) {
            throw new RuntimeException("不支持的周期: " + period);
        }
        limit = Math.max(1, Math.min(limit, 500));

        String key = symbol + "|" + period + "|" + limit;
        KlineCache cached = klineCache.get(key);
        long now = System.currentTimeMillis();

        if (cached != null && now - cached.fetchedAt < KLINE_TTL_MS) {
            return cached.bars; // TTL 内直接复用
        }
        try {
            List<Map<String, Object>> bars = RealMarketDataProvider.isCrypto(symbol)
                    ? realProvider.fetchCryptoKline(symbol, period, limit)
                    : realProvider.fetchAShareKline(symbol, period, limit);
            klineCache.put(key, new KlineCache(bars, now));
            return bars;
        } catch (Exception e) {
            log.warn("K线拉取失败 [{} {}]: {}", symbol, period, e.getMessage());
            if (cached != null) return cached.bars; // 保留上次真实K线
            throw new RuntimeException("K线暂时不可用,请稍后重试");
        }
    }

    // ───────────────────────── WebSocket 广播 ─────────────────────────

    /**
     * 每 2 秒把当前(真实)缓存广播给客户端;不修改价格。
     */
    @Scheduled(fixedRate = 2000)
    public void pushMarketData() {
        if (realSymbols.isEmpty() || wsHandler == null) return;

        Map<String, Object> snapshot = new HashMap<>();
        for (String symbol : realSymbols) {
            Quote q = quoteCache.get(symbol);
            if (q == null) continue;
            Map<String, Object> tickData = new HashMap<>();
            tickData.put("symbol", q.getSymbol());
            tickData.put("price", q.getPrice());
            tickData.put("change", q.getChange());
            tickData.put("timestamp", q.getTimestamp());
            snapshot.put(symbol, tickData);
        }
        if (snapshot.isEmpty()) return;

        Map<String, Object> payload = new HashMap<>();
        payload.put("type", "tick");
        payload.put("data", snapshot);
        wsHandler.broadcast(payload);
    }

    private static double num(Object o) {
        return o instanceof Number ? ((Number) o).doubleValue() : 0;
    }

    private static long lng(Object o) {
        return o instanceof Number ? ((Number) o).longValue() : System.currentTimeMillis();
    }

    private static final class KlineCache {
        final List<Map<String, Object>> bars;
        final long fetchedAt;

        KlineCache(List<Map<String, Object>> bars, long fetchedAt) {
            this.bars = bars;
            this.fetchedAt = fetchedAt;
        }
    }
}
