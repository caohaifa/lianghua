package com.aiquant.model;

import java.time.LocalDateTime;

/**
 * 邀请奖励流水(t_referral_reward):
 * 被推荐人(注册时填写邀请码建立 invited_by 关系)每笔现货成交,
 * 推荐人按成交流水 1% 获得返佣,入账到推荐人对应币种钱包。
 */
public class ReferralReward {

    private Long id;
    private String referrerId;   // 推荐人(获奖励方)
    private String traderId;     // 被推荐人(成交方)
    private String orderId;      // 触发返佣的订单
    private String symbol;       // 成交标的
    private String currency;     // 返佣币种(USDT/CNY,随交易币种)
    private Double volume;       // 成交额 = 成交价 × 成交量
    private Double reward;       // 返佣金额 = volume × 1%
    private LocalDateTime createdAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getReferrerId() { return referrerId; }
    public void setReferrerId(String referrerId) { this.referrerId = referrerId; }

    public String getTraderId() { return traderId; }
    public void setTraderId(String traderId) { this.traderId = traderId; }

    public String getOrderId() { return orderId; }
    public void setOrderId(String orderId) { this.orderId = orderId; }

    public String getSymbol() { return symbol; }
    public void setSymbol(String symbol) { this.symbol = symbol; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public Double getVolume() { return volume; }
    public void setVolume(Double volume) { this.volume = volume; }

    public Double getReward() { return reward; }
    public void setReward(Double reward) { this.reward = reward; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
