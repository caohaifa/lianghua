package com.aiquant.vo;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 运营后台:委托订单展示
 */
@Data
public class OrderAdminVO {
    private Long id;
    private String userId;
    private String orderId;
    private String symbol;
    private String currency;
    private String side;
    private String orderType;
    private Double price;
    private Double amount;
    private Double filledAmount;
    private String status;
    private String strategyName;
    private LocalDateTime createdAt;
}
