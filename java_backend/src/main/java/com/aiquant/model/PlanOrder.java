package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 订阅订单(t_plan_order)
 */
@Data
public class PlanOrder {
    private Long id;
    private String userId;
    private String planLevel;  // basic/pro
    private Double amount;
    private String period;     // month/year
    private String status;     // paid/refunded
    private LocalDateTime createdAt;
}
