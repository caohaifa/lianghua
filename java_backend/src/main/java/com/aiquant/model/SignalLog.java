package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 信号历史流水(t_signal_log):AI/机器人每轮产生的信号追加一行,
 * 与 t_monitor.signal(仅最新一条)互补,供后台绩效时间线展示。
 */
@Data
public class SignalLog {
    private Long id;
    private Long monitorId;
    private String userId;
    private String action;   // open_long/open_short/reject/wait
    private String signal;
    private LocalDateTime createdAt;
}
