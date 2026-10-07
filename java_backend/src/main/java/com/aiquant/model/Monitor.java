package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 用户自建监控(t_monitor)
 */
@Data
public class Monitor {
    private Long id;
    private String userId;
    private String symbol;
    private String strategy;
    private String status;   // running/paused
    private String signal;
    private String source;   // user/bot
    private String params;   // 个人策略自定义参数(JSON 对象字符串,键值对)
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
