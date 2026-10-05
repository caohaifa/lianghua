package com.aiquant.mapper;

import com.aiquant.model.Order;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface OrderMapper {

    @Insert("INSERT INTO t_order (user_id, order_id, symbol, side, order_type, price, amount, filled_amount, status, strategy_name, channel, created_at, updated_at) "
            +
            "VALUES (#{userId}, #{orderId}, #{symbol}, #{side}, #{orderType}, #{price}, #{amount}, #{filledAmount}, #{status}, #{strategyName}, #{channel}, NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Order order);

    @Select("SELECT * FROM t_order WHERE order_id = #{orderId}")
    Order selectByOrderId(String orderId);

    @Select("SELECT * FROM t_order WHERE user_id = #{userId} ORDER BY id DESC LIMIT #{limit}")
    List<Order> selectByUser(@Param("userId") String userId, @Param("limit") int limit);

    @Update("UPDATE t_order SET status = #{status}, filled_amount = #{filledAmount}, price = #{price}, updated_at = NOW() WHERE order_id = #{orderId}")
    int updateFill(Order order);

    @Update("UPDATE t_order SET status = 'cancelled', updated_at = NOW() WHERE order_id = #{orderId} AND status = 'pending'")
    int cancelPending(String orderId);

    @Select("SELECT * FROM t_order WHERE status = 'pending' ORDER BY id ASC")
    List<Order> selectAllPending();
}
