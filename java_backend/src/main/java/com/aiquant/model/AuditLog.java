package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 审计日志(后台操作留痕,合规要求保留 ≥ 5 年)
 */
@Data
public class AuditLog {
    private Long id;
    private String actorId;
    private Integer actorType;  // 0=用户 1=运营 2=系统
    private String action;
    private String resource;
    private String detailJson;
    private String ip;
    private LocalDateTime createTime;
}
