package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 跟单关系(t_strategy_follow):follower 按比例跟随 leader 某条监控的交易。
 */
@Data
public class StrategyFollow {
    private Long id;
    private String userId;     // follower
    private Long publishId;
    private String leaderId;
    private Long monitorId;
    private Integer ratio;     // 跟单比例 %(10/25/50/100),ratio 模式生效
    private String mode;       // 跟单模式: ratio=固定比例 balance=本金比例 fixed=固定倍数
    private Double fixedMultiplier; // 固定倍数模式的倍数 0.1~10
    private String status;     // active/paused/stopped
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    /** 以下为展示用附加字段(非表列) */
    private String title;         // 发布标题
    private String strategy;      // 策略名
    private String symbol;        // 标的
    private String leaderName;    // leader 昵称(脱敏)
    private String publishStatus; // 发布当前状态
    private Long tradeCount;      // 已复制笔数(t_copy_trade)
    private Double totalPnl;      // 已实现盈亏合计(卖出行 pnl 求和)
}
