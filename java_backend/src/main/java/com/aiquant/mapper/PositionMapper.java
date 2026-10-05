package com.aiquant.mapper;

import com.aiquant.model.Position;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface PositionMapper {

    @Insert("INSERT INTO t_position (user_id, symbol, side, amount, available_amount, entry_price, current_price, pnl, pnl_pct, status, opened_at) "
            +
            "VALUES (#{userId}, #{symbol}, #{side}, #{amount}, #{availableAmount}, #{entryPrice}, #{currentPrice}, 0, 0, 0, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Position position);

    @Select("SELECT * FROM t_position WHERE user_id = #{userId} AND symbol = #{symbol} AND side = #{side} AND status = 0")
    Position selectOpen(@Param("userId") String userId, @Param("symbol") String symbol, @Param("side") String side);

    @Select("SELECT * FROM t_position WHERE user_id = #{userId} AND status = 0 ORDER BY id DESC")
    List<Position> selectOpenByUser(String userId);

    @Select("SELECT COUNT(*) FROM t_position WHERE user_id = #{userId} AND status = 0")
    int countOpen(String userId);

    @Update("UPDATE t_position SET amount = #{amount}, available_amount = #{availableAmount}, "
            +
            "entry_price = #{entryPrice}, current_price = #{currentPrice}, "
            +
            "pnl = #{pnl}, pnl_pct = #{pnlPct} WHERE id = #{id}")
    int updateHolding(Position position);

    /** A股 T+1 解冻:工作日开盘前把持仓中昨日及之前买入的冻结份额(available<amount)全部转为可卖 */
    @Update("UPDATE t_position SET available_amount = amount "
            +
            "WHERE status = 0 AND symbol NOT LIKE '%/%' AND available_amount < amount")
    int releaseAshare();

    @Update("UPDATE t_position SET status = 1, current_price = #{currentPrice}, pnl = #{pnl}, pnl_pct = #{pnlPct}, closed_at = NOW() WHERE id = #{id}")
    int close(Position position);

    /** 按用户汇总区间内已平仓仓位的已实现盈亏(月度分成结算数据源) */
    @Select("SELECT user_id AS userId, SUM(pnl) AS profit FROM t_position " +
            "WHERE status = 1 AND closed_at >= #{start} AND closed_at < #{end} GROUP BY user_id")
    List<java.util.Map<String, Object>> sumClosedPnlByUser(@Param("start") String start, @Param("end") String end);
}
