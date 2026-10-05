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
    private String currency;   // USDT / CNY
    private String market;     // crypto / a-share
    private long timestamp;

    /** 按 (symbol,name,price,change,volume,currency,market,timestamp) 构造 */
    public static Quote of(String symbol, String name, double price, double change,
                           double volume, String currency, String market, long timestamp) {
        Quote q = new Quote();
        q.symbol = symbol;
        q.name = name;
        q.price = price;
        q.change = change;
        q.volume = volume;
        q.currency = currency;
        q.market = market;
        q.timestamp = timestamp;
        return q;
    }
}
