package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class RiskAssessment {
    private Long id;
    private String userId;
    private String riskLevel;  // R1~R5
    private Integer score;
    private String answersJson;
    private LocalDateTime assessedAt;
}
