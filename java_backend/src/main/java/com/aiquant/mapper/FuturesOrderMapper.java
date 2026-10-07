package com.aiquant.mapper;

import com.aiquant.model.FuturesOrder;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface FuturesOrderMapper {

    @Insert("INSERT INTO t_futures_order (user_id, order_id, symbol, direction, action, amount, "
            + "price, leverage, margin, fee, pnl, created_at) "
            + "VALUES (#{userId}, #{orderId}, #{symbol}, #{direction}, #{action}, #{amount}, "
            + "#{price}, #{leverage}, #{margin}, #{fee}, #{pnl}, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(FuturesOrder order);

    @Select("SELECT * FROM t_futures_order WHERE user_id = #{userId} ORDER BY id DESC LIMIT #{limit}")
    List<FuturesOrder> selectByUser(@Param("userId") String userId, @Param("limit") int limit);
}
