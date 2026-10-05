package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 委托订单(t_order)
 */
@Data
public class Order {
    private Long id;
    private String userId;
    private String orderId;
    private String symbol;
    private String side;        // buy/sell
    private String orderType;   // market/limit
    private Double price;       // 限价单价格;市价单为成交价
    private Double amount;
    private Double filledAmount;
    private String status;      // pending/filled/cancelled
    private String strategyName;
    private String signalId;
    private String channel;     // sim/binance 成交通道
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
