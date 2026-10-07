package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class Banner {
    private Long id;
    private String title;
    private String imageUrl;
    private String linkType;   // none / url / strategy / announcement
    private String linkUrl;
    private Integer position;
    private Integer status;    // 0=禁用 1=启用
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private String creator;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
