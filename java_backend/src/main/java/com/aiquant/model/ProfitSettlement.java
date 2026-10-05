package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 分成结算记录(t_profit_settlement)
 */
@Data
public class ProfitSettlement {
    private Long id;
    private String userId;
    private Double profitAmount;
    private Double shareRatio;
    private Double shareAmount;
    private LocalDateTime settledAt;
}
