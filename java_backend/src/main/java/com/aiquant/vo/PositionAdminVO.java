package com.aiquant.vo;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 运营后台:持仓展示
 */
@Data
public class PositionAdminVO {
    private Long id;
    private String userId;
    private String symbol;
    private String currency;
    private String side;
    private Double amount;
    private Double entryPrice;
    private Double currentPrice;
    private Double pnl;
    private Double pnlPct;
    private String strategyName;
    private Integer status;
    private LocalDateTime openedAt;
    private LocalDateTime closedAt;
}
