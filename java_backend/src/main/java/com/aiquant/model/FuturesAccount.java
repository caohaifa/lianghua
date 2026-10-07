package com.aiquant.model;

import lombok.Data;
import java.time.LocalDateTime;

/**
 * 合约账户(t_futures_account):USDT 本位永续模拟账户。
 * 钱包余额含占用保证金;可用 = 钱包余额 - 占用保证金;权益 = 钱包余额 + 未实现盈亏。
 */
@Data
public class FuturesAccount {
    private Long id;
    private String userId;
    private Double walletBalance;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
