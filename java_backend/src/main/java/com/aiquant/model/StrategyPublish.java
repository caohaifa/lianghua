package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 策略发布(t_strategy_publish):会员把自己的监控申请发布到策略广场,
 * 后台审核通过(published)后才展示、可被跟单。
 */
@Data
public class StrategyPublish {
    private Long id;
    private String leaderId;
    private Long monitorId;
    private String title;
    private String description;
    private String strategy;
    private String symbol;
    private String status;   // pending/published/rejected/offline
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    /** 以下为展示用附加字段(非表列) */
    private String leaderName;    // 昵称,空则手机号脱敏
    private long followers;       // active 跟单人数
    private Integer isBot;        // 1=系统量化机器人
}
