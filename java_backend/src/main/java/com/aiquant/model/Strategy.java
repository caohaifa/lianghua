package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 策略(策略上下架 / 灰度放量)
 * 状态流转: draft 草稿 → review 待审核 → gray 灰度 → online 已上架 → offline 已下架
 */
@Data
public class Strategy {
    private Long id;
    private String strategyId;
    private String name;
    private String description;
    private String exchange;
    private String symbols;
    private String status;
    private String riskLevel;
    private Integer grayPercent;  // 灰度放量比例 0~100
    private String creator;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
