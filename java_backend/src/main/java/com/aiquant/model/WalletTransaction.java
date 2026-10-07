package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 钱包流水(t_wallet_transaction):充值/提现记录。
 */
@Data
public class WalletTransaction {
    private Long id;
    private String userId;
    private String currency;     // USDT / CNY
    private String type;         // deposit / withdraw
    private Double amount;
    private String channel;      // 充值渠道 / 提现网络
    private String address;      // 提现地址
    private String status;       // completed
    private LocalDateTime createdAt;
}
