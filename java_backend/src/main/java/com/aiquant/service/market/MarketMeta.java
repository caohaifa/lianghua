package com.aiquant.service.market;

import com.aiquant.model.Quote;

import java.util.*;

/**
 * 币种静态元数据:品牌色(前端币种圆点)+ 流通供应量(市值估算)。
 * 供应量为约值,用于行情首页总市值卡片,随真实价格浮动。
 */
public class MarketMeta {

    // symbol -> 品牌色
    private static final Map<String, String> COLORS = new LinkedHashMap<>();
    // symbol -> 流通供应量(枚)
    private static final Map<String, Double> SUPPLY = new LinkedHashMap<>();

    private static void put(String symbol, String color, double supply) {
        COLORS.put(symbol, color);
        SUPPLY.put(symbol, supply);
    }

    static {
        put("BTC/USDT", "F7931A", 19_700_000d);
        put("ETH/USDT", "627EEA", 120_400_000d);
        put("SOL/USDT", "9945FF", 440_000_000d);
        put("BNB/USDT", "F0B90B", 147_600_000d);
        put("XRP/USDT", "00A5DF", 55_000_000_000d);
        put("DOGE/USDT", "C2A633", 143_000_000_000d);
        put("ADA/USDT", "0033AD", 35_000_000_000d);
        put("AVAX/USDT", "E84142", 370_000_000d);
        put("DOT/USDT", "E6007A", 1_400_000_000d);
        put("LINK/USDT", "2A5ADA", 590_000_000d);
        put("TRX/USDT", "FF060A", 87_000_000_000d);
        put("LTC/USDT", "345D9D", 74_000_000d);
        put("TON/USDT", "0098EA", 3_500_000_000d);
        put("ATOM/USDT", "6F7390", 390_000_000d);
        put("NEAR/USDT", "00EC97", 1_100_000_000d);
        put("SHIB/USDT", "FFA409", 589_000_000_000_000d);
        put("UNI/USDT", "FF007A", 750_000_000d);
        put("XLM/USDT", "08B5E5", 28_000_000_000d);
        put("FIL/USDT", "0090FF", 530_000_000d);
        put("APT/USDT", "2DD8A7", 420_000_000d);
        put("ARB/USDT", "28A0F0", 3_100_000_000d);
        put("OP/USDT", "FF0420", 1_100_000_000d);
        put("INJ/USDT", "00B4FF", 94_000_000d);
        put("SUI/USDT", "4DA2FF", 2_600_000_000d);
        put("PEPE/USDT", "3D9B35", 420_000_000_000_000d);
        put("AAVE/USDT", "B65090", 14_700_000d);
        put("ALGO/USDT", "0FB5BA", 7_800_000_000d);
        put("FTM/USDT", "1969FF", 2_800_000_000d);
        put("EOS/USDT", "543CD8", 1_500_000_000d);
        put("GRT/USDT", "6747ED", 9_500_000_000d);

        // ── A 股:指数(深蓝) + 个股(品牌红/科技蓝/消费绿等) ──
        put("000001", "1A3C6E", 0);   // 上证指数
        put("000300", "1A3C6E", 0);   // 沪深300
        put("399001", "C41230", 0);   // 深证成指
        put("399006", "C41230", 0);   // 创业板指
        put("000688", "1A3C6E", 0);   // 科创50
        put("600519", "C41230", 0);   // 贵州茅台
        put("300750", "2E7D32", 0);   // 宁德时代
        put("002594", "1565C0", 0);   // 比亚迪
        put("601318", "C41230", 0);   // 中国平安
        put("600036", "1565C0", 0);   // 招商银行
        put("000858", "C41230", 0);   // 五粮液
        put("601012", "2E7D32", 0);   // 隆基绿能
        put("300059", "E65100", 0);   // 东方财富
        put("688981", "1565C0", 0);   // 中芯国际
        put("000333", "1565C0", 0);   // 美的集团
        put("000016", "1A3C6E", 0);   // 上证50
        put("000905", "1A3C6E", 0);   // 中证500
        put("600030", "C41230", 0);   // 中信证券
        put("600276", "2E7D32", 0);   // 恒瑞医药
        put("600887", "C41230", 0);   // 伊利股份
        put("601888", "E65100", 0);   // 中国中免
        put("600900", "1565C0", 0);   // 长江电力
        put("601899", "E65100", 0);   // 紫金矿业
        put("002415", "1565C0", 0);   // 海康威视
        put("000063", "1565C0", 0);   // 中兴通讯
        put("002475", "1565C0", 0);   // 立讯精密
        put("601088", "424242", 0);   // 中国神华
        put("600028", "C41230", 0);   // 中国石化
        put("601668", "424242", 0);   // 中国建筑
        put("603288", "2E7D32", 0);   // 海天味业
    }

    /** 币种品牌色表 {symbol: "#hex"} */
    public static Map<String, String> colorMap() {
        Map<String, String> m = new LinkedHashMap<>();
        COLORS.forEach((k, v) -> m.put(k, "#" + v));
        return m;
    }

    /**
     * 行情总览:加密总市值 + 24h 总成交额 + BTC 占比。
     * 市值 = price * 流通供应量(仅已知供应量的币种)。
     */
    public static Map<String, Object> overview(Collection<Quote> quotes) {
        double marketCap = 0, totalVol = 0, btcCap = 0;
        int count = 0;
        for (Quote q : quotes) {
            if (!"crypto".equals(q.getMarket())) continue;
            count++;
            Double supply = SUPPLY.get(q.getSymbol());
            if (supply != null) {
                double cap = q.getPrice() * supply;
                marketCap += cap;
                if ("BTC/USDT".equals(q.getSymbol())) btcCap = cap;
            }
            totalVol += q.getQuoteVol();
        }
        Map<String, Object> vo = new LinkedHashMap<>();
        vo.put("total_market_cap", Math.round(marketCap * 100) / 100d);
        vo.put("total_24h_volume", Math.round(totalVol * 100) / 100d);
        vo.put("btc_dominance", marketCap > 0 ? Math.round(btcCap / marketCap * 10000) / 100d : 0);
        vo.put("active_cryptos", count);
        return vo;
    }
}
