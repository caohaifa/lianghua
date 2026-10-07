package com.aiquant.mapper;

import com.aiquant.model.CopyTrade;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface CopyTradeMapper {

    @Insert("INSERT INTO t_copy_trade (follow_id, user_id, publish_id, monitor_id, symbol, side, amount, price, pnl, order_id, created_at) "
            + "VALUES (#{followId}, #{userId}, #{publishId}, #{monitorId}, #{symbol}, #{side}, #{amount}, #{price}, #{pnl}, #{orderId}, NOW())")
    int insert(CopyTrade trade);
}
