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
    /**
     * 订单状态机:
     *   pending        挂单等待成交(限价单)
     *   filled         全部成交
     *   cancelled      已撤销
     *   rejected       交易所拒单(终态,原因为 fail_reason)
     *   partial_filled 部分成交(成交部分已入账,剩余由交易所继续撮合/待对账)
     *   expired        已过期(终态)
     *   unknown        提交结果未知(交易所超时,待对账,不可自动撤单/重试)
     */
    private String status;
    private String failReason;  // rejected/unknown 时的失败或对账说明
    private String strategyName;
    private String signalId;
    private String channel;     // sim/binance 成交通道
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
