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
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
