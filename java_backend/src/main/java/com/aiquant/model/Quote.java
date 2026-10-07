package com.aiquant.model;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Quote {
    private String symbol;
    private String name;
    private double price;
    private double change;      // 涨跌幅 %
    private double volume;     // 成交量
    private double high;       // 24h最高
    private double low;        // 24h最低
    private double quoteVol;   // 成交额(USDT/CNY)
    private String currency;   // USDT / CNY
    private String market;     // crypto / a-share
    private long timestamp;

    /** 按 (symbol,name,price,change,volume,currency,market,timestamp) 构造(24h 字段为 0) */
    public static Quote of(String symbol, String name, double price, double change,
                           double volume, String currency, String market, long timestamp) {
        return ofFull(symbol, name, price, change, volume, 0, 0, 0, currency, market, timestamp);
    }

    /** 全字段构造(含 24h 高/低/成交额) */
    public static Quote ofFull(String symbol, String name, double price, double change,
                               double volume, double high, double low, double quoteVol,
                               String currency, String market, long timestamp) {
        Quote q = new Quote();
        q.symbol = symbol;
        q.name = name;
        q.price = price;
        q.change = change;
        q.volume = volume;
        q.high = high;
        q.low = low;
        q.quoteVol = quoteVol;
        q.currency = currency;
        q.market = market;
        q.timestamp = timestamp;
        return q;
    }
}
