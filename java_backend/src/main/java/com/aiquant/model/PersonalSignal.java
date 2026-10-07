package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 个人策略信号流水(t_personal_signal):主交易员在信号台人工下发,
 * 机器人按跟单模式自动为 follower 换算仓位执行开/加/平仓。
 */
@Data
public class PersonalSignal {
    private Long id;
    private Long monitorId;
    private String userId;      // 信号发起人(策略主)
    private String action;      // open_long/add_long/partial_close/close_all/open_short
    private Double amount;      // 数量(开仓/加仓/平空量)
    private Integer ratioPct;   // 部分平仓百分比 1-99
    private Integer leverage;   // 开空杠杆 1-125
    private Integer okCount;    // follower 执行成功数
    private Integer skipCount;  // 跳过/失败数
    private String detail;      // 分发明细摘要
    private LocalDateTime createdAt;
}
