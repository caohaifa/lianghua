package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 网格机器人档位(t_bot_grid_level):价格触及触发价时买/卖,成交后生成对手档。
 */
@Data
public class BotGridLevel {
    private Long id;
    private Long monitorId;
    private Integer gridIdx;
    private Double triggerPrice;
    private String side;     // buy/sell
    private Double amount;
    private String status;   // open/filled/closed
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
