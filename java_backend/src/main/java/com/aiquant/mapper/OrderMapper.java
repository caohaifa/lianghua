package com.aiquant.mapper;

import com.aiquant.model.Order;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface OrderMapper {

    @Insert("INSERT INTO t_order (user_id, order_id, symbol, side, order_type, price, amount, filled_amount, status, fail_reason, strategy_name, channel, created_at, updated_at) "
            +
            "VALUES (#{userId}, #{orderId}, #{symbol}, #{side}, #{orderType}, #{price}, #{amount}, #{filledAmount}, #{status}, #{failReason}, #{strategyName}, #{channel}, NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Order order);

    @Select("SELECT * FROM t_order WHERE order_id = #{orderId}")
    Order selectByOrderId(String orderId);

    @Select("SELECT * FROM t_order WHERE user_id = #{userId} ORDER BY id DESC LIMIT #{limit}")
    List<Order> selectByUser(@Param("userId") String userId, @Param("limit") int limit);

    @Select("SELECT * FROM t_order WHERE user_id = #{userId} AND symbol = #{symbol} ORDER BY id DESC LIMIT #{limit}")
    List<Order> selectByUserAndSymbol(@Param("userId") String userId, @Param("symbol") String symbol, @Param("limit") int limit);

    @Update("UPDATE t_order SET status = #{status}, filled_amount = #{filledAmount}, price = #{price}, updated_at = NOW() WHERE order_id = #{orderId}")
    int updateFill(Order order);

    /** 异常路径状态回写:拒单/超时对账/过期(不改成交数量与价格) */
    @Update("UPDATE t_order SET status = #{status}, fail_reason = #{failReason}, updated_at = NOW() WHERE order_id = #{orderId}")
    int updateStatus(@Param("orderId") String orderId, @Param("status") String status, @Param("failReason") String failReason);

    @Update("UPDATE t_order SET status = 'cancelled', updated_at = NOW() WHERE order_id = #{orderId} AND status = 'pending'")
    int cancelPending(String orderId);

    @Select("SELECT * FROM t_order WHERE status = 'pending' ORDER BY id ASC")
    List<Order> selectAllPending();

    @Select("SELECT COUNT(*) FROM t_order WHERE user_id = #{userId}")
    long countByUser(String userId);

    @Select("SELECT COUNT(*) FROM t_order WHERE user_id = #{userId} AND status = #{status}")
    long countByUserAndStatus(@Param("userId") String userId, @Param("status") String status);

    /** 累计成交金额(按已成交订单 price×filled_amount 求和,币种混合仅示意) */
    @Select("SELECT COALESCE(SUM(price * filled_amount), 0) FROM t_order WHERE user_id = #{userId} AND status = 'filled'")
    double sumFilledTurnover(String userId);
}
