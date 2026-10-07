package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 开源策略量化机器人(t_quant_bot):系统虚拟带单员。
 * 一个机器人 = 一个系统用户 + 一条 source='bot' 的监控 + 一条自动通过的发布。
 */
@Data
public class QuantBot {
    private Long id;
    private String botUserId;
    private Long monitorId;
    private String strategyKey;   // ema_cross/rsi_rev/grid/boll_break
    private String symbol;
    private String configJson;
    private LocalDateTime createdAt;
}
