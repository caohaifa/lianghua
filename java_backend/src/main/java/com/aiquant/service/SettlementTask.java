package com.aiquant.service;

import com.aiquant.mapper.PositionMapper;
import com.aiquant.mapper.SubscriptionMapper;
import com.aiquant.model.ProfitSettlement;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

/**
 * 月度分成结算引擎:每月 1 日 00:30 对上一自然月的已实现盈利生成结算记录。
 * 梯度分成比例(设计文档 §分成规则):
 *   净盈利 < 10 万 → 10%;10~50 万 → 12%;> 50 万 → 15%
 * 数据源:区间内已平仓仓位的已实现盈亏合计;仅盈利 > 0 的用户生成结算。
 * 幂等:同一用户当月已存在结算记录则跳过。
 */
@Component
public class SettlementTask {

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Autowired
    private PositionMapper positionMapper;
    @Autowired
    private SubscriptionMapper subscriptionMapper;

    @Scheduled(cron = "0 30 0 1 * ?")
    public void settleMonthly() {
        LocalDate firstOfMonth = LocalDate.now().withDayOfMonth(1);
        LocalDate prevFirst = firstOfMonth.minusMonths(1);
        String start = prevFirst.atStartOfDay().format(FMT);
        String end = firstOfMonth.atStartOfDay().format(FMT);
        String guardSince = firstOfMonth.atStartOfDay().format(FMT);

        List<Map<String, Object>> rows = positionMapper.sumClosedPnlByUser(start, end);
        int created = 0;
        for (Map<String, Object> row : rows) {
            String userId = (String) row.get("userId");
            double profit = ((Number) row.get("profit")).doubleValue();
            if (profit <= 0) continue; // 亏损/零盈利不参与分成
            if (subscriptionMapper.countSettlementsSince(userId, guardSince) > 0) continue; // 幂等

            double ratio = shareRatio(profit);
            ProfitSettlement s = new ProfitSettlement();
            s.setUserId(userId);
            s.setProfitAmount(round2(profit));
            s.setShareRatio(ratio);
            s.setShareAmount(round2(profit * ratio / 100));
            subscriptionMapper.insertSettlement(s);
            created++;
        }
        System.out.println("[SETTLE] " + prevFirst + " 月度分成结算完成,共生成 " + created + " 条");
    }

    /** 梯度分成比例(%) */
    private double shareRatio(double profit) {
        if (profit > 500_000) return 15.0;
        if (profit >= 100_000) return 12.0;
        return 10.0;
    }

    private double round2(double v) {
        return Math.round(v * 100.0) / 100.0;
    }
}
