package com.aiquant.vo;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 运营后台:订阅订单展示
 */
@Data
public class PlanOrderAdminVO {
    private Long id;
    private String userId;
    private String planLevel;
    private Double amount;
    private String period;
    private String status;
    private LocalDateTime createdAt;
}
