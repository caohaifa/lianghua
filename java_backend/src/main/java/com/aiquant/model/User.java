package com.aiquant.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import lombok.Data;
import java.time.LocalDateTime;

@Data
public class User {
    private Long id;
    private String userId;
    private String phone;
    @JsonIgnore  // 密码哈希永不返回给任何客户端
    private String passwordHash;
    private String nickname;
    private String avatar;
    private String riskLevel;  // R1~R5
    private Boolean agreementSigned;
    private String deviceId;
    private String tradingMode;  // sim=模拟盘 live=实盘
    private Integer status;  // 0=正常 1=冻结
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
