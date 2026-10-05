package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 持仓(t_position)
 */
@Data
public class Position {
    private Long id;
    private String userId;
    private String symbol;
    private String side;       // long/short
    private Double amount;
    private Double availableAmount; // T+1 可卖份额
    private Double entryPrice;
    private Double currentPrice;
    private Double pnl;
    private Double pnlPct;
    private String strategyName;
    private Integer status;    // 0=持仓中 1=已平仓
    private LocalDateTime openedAt;
    private LocalDateTime closedAt;
}
