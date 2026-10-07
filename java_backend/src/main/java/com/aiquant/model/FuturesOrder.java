package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 合约成交记录(t_futures_order):市价开/平仓流水。
 */
@Data
public class FuturesOrder {
    private Long id;
    private String userId;
    private String orderId;
    private String symbol;
    private String direction;   // long/short
    private String action;      // open/close
    private Double amount;
    private Double price;
    private Integer leverage;
    private Double margin;
    private Double fee;
    private Double pnl;         // 平仓已实现盈亏(开仓为0)
    private LocalDateTime createdAt;
}
