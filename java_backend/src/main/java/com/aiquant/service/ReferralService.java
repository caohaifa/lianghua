package com.aiquant.service;

import com.aiquant.mapper.AccountMapper;
import com.aiquant.mapper.ReferralRewardMapper;
import com.aiquant.mapper.UserMapper;
import com.aiquant.model.ReferralReward;
import com.aiquant.model.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 邀请奖励:被推荐人(注册时填写邀请码建立 t_user.invited_by 关系)每笔现货成交,
 * 推荐人按成交流水 1% 获得返佣,入账到推荐人对应币种钱包并落 t_referral_reward。
 * 与 CopyTradingService 同策略:发放失败仅记日志,不影响主交易事务。
 */
@Service
public class ReferralService {

    private static final Logger log = LoggerFactory.getLogger(ReferralService.class);

    /** 返佣比例:交易流水 1% */
    public static final double RATE = 0.01;

    @Autowired private UserMapper userMapper;
    @Autowired private AccountMapper accountMapper;
    @Autowired private ReferralRewardMapper rewardMapper;

    /**
     * 成交后发放邀请奖励(在成交入账事务内调用)。
     *
     * @param traderId 被推荐人(成交用户)
     * @param orderId  订单号
     * @param symbol   成交标的
     * @param currency 结算币种(USDT/CNY,与该笔交易一致,不混算)
     * @param notional 成交额 = 成交价 × 成交量
     */
    public void payReward(String traderId, String orderId, String symbol,
                          String currency, double notional) {
        try {
            if (notional <= 0) return;
            User trader = userMapper.selectByUserId(traderId);
            String referrerId = trader == null ? null : trader.getInvitedBy();
            if (referrerId == null || referrerId.isBlank() || referrerId.equals(traderId)) return;

            double reward = round8(notional * RATE);
            if (reward <= 0) return;

            // 推荐人对应币种账户懒初始化后入账(与交易侧 ensureAccount 同规则)
            if (accountMapper.selectByUserAndCurrency(referrerId, currency) == null) {
                if ("CNY".equals(currency)) accountMapper.initCny(referrerId);
                else accountMapper.initUsdt(referrerId);
            }
            accountMapper.addBalance(referrerId, currency, reward);

            ReferralReward r = new ReferralReward();
            r.setReferrerId(referrerId);
            r.setTraderId(traderId);
            r.setOrderId(orderId);
            r.setSymbol(symbol);
            r.setCurrency(currency);
            r.setVolume(round8(notional));
            r.setReward(reward);
            rewardMapper.insert(r);
        } catch (Exception e) {
            log.warn("邀请奖励发放失败 trader={} order={}", traderId, orderId, e);
        }
    }

    private double round8(double v) {
        return Math.round(v * 1e8) / 1e8;
    }
}
