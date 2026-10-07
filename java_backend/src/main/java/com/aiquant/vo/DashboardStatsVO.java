package com.aiquant.vo;

import lombok.Data;

/**
 * 数据看板核心指标
 */
@Data
public class DashboardStatsVO {
    private Long totalUsers;
    private Long todayNewUsers;
    private Long frozenUsers;
    private Long dau;
    private Double tradeVolume;
    private Long orderCount;
    private Long onlineStrategies;
    private Long openPositions;
}
