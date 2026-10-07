package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 跟单复制流水(t_copy_trade):每次复制成交记一行,卖出行记已实现盈亏 pnl。
 */
@Data
public class CopyTrade {
    private Long id;
    private Long followId;
    private String userId;      // follower
    private Long publishId;
    private Long monitorId;
    private String symbol;
    private String side;        // buy/sell
    private Double amount;
    private Double price;
    private Double pnl;         // 仅 sell 行有值:(成交价-持仓均价)×数量
    private String orderId;
    private LocalDateTime createdAt;
}
