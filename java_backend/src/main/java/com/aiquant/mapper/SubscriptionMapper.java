package com.aiquant.mapper;

import com.aiquant.model.PlanOrder;
import com.aiquant.model.ProfitSettlement;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface SubscriptionMapper {

    @Insert("INSERT INTO t_plan_order (user_id, plan_level, amount, period, status, created_at) "
            +
            "VALUES (#{userId}, #{planLevel}, #{amount}, #{period}, #{status}, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insertPlanOrder(PlanOrder order);

    /** 用户最后一笔已支付订单(是否到期由 SubscriptionService 判定) */
    @Select("SELECT * FROM t_plan_order WHERE user_id = #{userId} AND status = 'paid' ORDER BY id DESC LIMIT 1")
    PlanOrder selectLatestPaid(String userId);

    @Select("SELECT * FROM t_plan_order WHERE user_id = #{userId} ORDER BY id DESC LIMIT #{limit}")
    List<PlanOrder> selectPlanOrders(@Param("userId") String userId, @Param("limit") int limit);

    @Select("SELECT * FROM t_profit_settlement WHERE user_id = #{userId} ORDER BY id DESC LIMIT #{limit}")
    List<ProfitSettlement> selectSettlements(@Param("userId") String userId, @Param("limit") int limit);

    @Insert("INSERT INTO t_profit_settlement (user_id, profit_amount, share_ratio, share_amount, settled_at) " +
            "VALUES (#{userId}, #{profitAmount}, #{shareRatio}, #{shareAmount}, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insertSettlement(ProfitSettlement settlement);

    /** 幂等护栏:统计某用户指定时间点后已生成的结算记录数 */
    @Select("SELECT COUNT(*) FROM t_profit_settlement WHERE user_id = #{userId} AND settled_at >= #{since}")
    int countSettlementsSince(@Param("userId") String userId, @Param("since") String since);
}
