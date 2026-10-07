package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class PushNotification {
    private Long id;
    private String title;
    private String content;
    private String targetType;   // all / risk_level / user_ids
    private String targetValue;
    private Integer status;      // 0=草稿 1=待发送 2=已发送 3=已取消
    private LocalDateTime scheduledAt;
    private LocalDateTime sentAt;
    private Integer sentCount;
    private String creator;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
