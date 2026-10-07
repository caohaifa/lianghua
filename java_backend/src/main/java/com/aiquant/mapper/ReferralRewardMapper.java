package com.aiquant.mapper;

import com.aiquant.model.ReferralReward;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.Map;

/** 邀请奖励流水 t_referral_reward */
public interface ReferralRewardMapper {

    @Insert("INSERT INTO t_referral_reward (referrer_id, trader_id, order_id, symbol, currency, volume, reward, created_at) "
            + "VALUES (#{referrerId}, #{traderId}, #{orderId}, #{symbol}, #{currency}, #{volume}, #{reward}, NOW())")
    int insert(ReferralReward r);

    @Select("SELECT * FROM t_referral_reward WHERE referrer_id = #{referrerId} "
            + "ORDER BY id DESC LIMIT #{limit}")
    List<ReferralReward> selectByReferrer(@Param("referrerId") String referrerId,
                                          @Param("limit") int limit);

    @Select("SELECT COALESCE(SUM(reward), 0) FROM t_referral_reward "
            + "WHERE referrer_id = #{referrerId} AND currency = #{currency}")
    double sumReward(@Param("referrerId") String referrerId,
                     @Param("currency") String currency);

    @Select("SELECT COUNT(*) FROM t_user WHERE invited_by = #{referrerId}")
    long countInvited(@Param("referrerId") String referrerId);

    // ══════════════════════ 团队管理 ══════════════════════

    /** 团队交易总流水(指定币种) */
    @Select("SELECT COALESCE(SUM(volume), 0) FROM t_referral_reward "
            + "WHERE referrer_id = #{referrerId} AND currency = #{currency}")
    double sumVolume(@Param("referrerId") String referrerId,
                     @Param("currency") String currency);

    /** 活跃成员数(有成交流水的去重被推荐人数) */
    @Select("SELECT COUNT(DISTINCT trader_id) FROM t_referral_reward WHERE referrer_id = #{referrerId}")
    long countActiveTraders(@Param("referrerId") String referrerId);

    /** 成员流水/返佣聚合(别名不带下划线,规避 H2/MySQL 列标签大小写差异) */
    @Select("SELECT trader_id AS traderid, COUNT(*) AS tradecount, "
            + "SUM(CASE WHEN currency = 'USDT' THEN volume ELSE 0 END) AS volusdt, "
            + "SUM(CASE WHEN currency = 'CNY' THEN volume ELSE 0 END) AS volcny, "
            + "SUM(CASE WHEN currency = 'USDT' THEN reward ELSE 0 END) AS rewardusdt, "
            + "SUM(CASE WHEN currency = 'CNY' THEN reward ELSE 0 END) AS rewardcny "
            + "FROM t_referral_reward WHERE referrer_id = #{referrerId} GROUP BY trader_id")
    List<Map<String, Object>> selectMemberStats(@Param("referrerId") String referrerId);

    /** 团队成员基础信息(别名不带下划线,同上) */
    @Select("SELECT user_id AS userid, nickname, phone, created_at AS createdat FROM t_user "
            + "WHERE invited_by = #{referrerId} ORDER BY created_at DESC, user_id LIMIT #{limit}")
    List<Map<String, Object>> selectInvitedUsers(@Param("referrerId") String referrerId,
                                                 @Param("limit") int limit);
}
