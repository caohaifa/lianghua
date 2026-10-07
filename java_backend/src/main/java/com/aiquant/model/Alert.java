package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 站内告警(t_alert):跟单跳过/风控事件/系统消息。
 */
@Data
public class Alert {
    private Long id;
    private String userId;
    private String type;       // copy_skip/risk/system
    private String title;
    private String content;
    private Integer readFlag;  // 0=未读 1=已读
    private LocalDateTime createdAt;
}
