package com.aiquant.vo;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 运营后台:分成结算展示
 */
@Data
public class SettlementAdminVO {
    private Long id;
    private String userId;
    private Double profitAmount;
    private Double shareRatio;
    private Double shareAmount;
    private LocalDateTime settledAt;
}
