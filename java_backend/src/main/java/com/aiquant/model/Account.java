package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 模拟账户(t_account)
 */
@Data
public class Account {
    private Long id;
    private String userId;
    private String currency;
    private Double balance;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
