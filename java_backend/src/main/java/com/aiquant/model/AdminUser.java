package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 管理员(RBAC)
 * 角色: super_admin 超管 / ops 运营 / compliance 合规 / finance 财务
 */
@Data
public class AdminUser {
    private Long id;
    private String username;
    private String passwordHash;
    private String realName;
    private String role;
    private Integer status;  // 0=正常 1=停用
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
