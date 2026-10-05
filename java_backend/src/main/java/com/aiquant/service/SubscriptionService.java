package com.aiquant.service;

import com.aiquant.mapper.SubscriptionMapper;
import com.aiquant.model.PlanOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

/**
 * 订阅服务:套餐有效期判定 + 权益上限。
 * month=30 天 / year=365 天,到期后按免费版处理;
 * 权益:监控数量上限 free=1 / basic=5 / pro=20。
 */
@Service
public class SubscriptionService {

    public static final int LIMIT_FREE = 1;
    public static final int LIMIT_BASIC = 5;
    public static final int LIMIT_PRO = 20;

    @Autowired
    private SubscriptionMapper subscriptionMapper;

    /** 当前有效套餐(最后一笔 paid 且未到期);无则 null */
    public PlanOrder getActivePlan(String userId) {
        PlanOrder latest = subscriptionMapper.selectLatestPaid(userId);
        if (latest == null || latest.getCreatedAt() == null) return null;
        int days = "year".equals(latest.getPeriod()) ? 365 : 30;
        LocalDateTime expireAt = latest.getCreatedAt().plusDays(days);
        return expireAt.isAfter(LocalDateTime.now()) ? latest : null;
    }

    /** 监控数量上限(按当前有效套餐) */
    public int getMonitorLimit(String userId) {
        PlanOrder plan = getActivePlan(userId);
        if (plan == null) return LIMIT_FREE;
        return "pro".equals(plan.getPlanLevel()) ? LIMIT_PRO : LIMIT_BASIC;
    }
}
