package com.aiquant.mapper;

import com.aiquant.model.FuturesPosition;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface FuturesPositionMapper {

    @Insert("INSERT INTO t_futures_position (user_id, symbol, direction, amount, entry_price, "
            + "leverage, margin, status, opened_at) "
            + "VALUES (#{userId}, #{symbol}, #{direction}, #{amount}, #{entryPrice}, "
            + "#{leverage}, #{margin}, 0, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(FuturesPosition position);

    @Select("SELECT * FROM t_futures_position WHERE user_id = #{userId} AND symbol = #{symbol} "
            + "AND status = 0")
    FuturesPosition selectOpenBySymbol(@Param("userId") String userId,
                                       @Param("symbol") String symbol);

    @Select("SELECT * FROM t_futures_position WHERE user_id = #{userId} AND status = 0 ORDER BY id DESC")
    List<FuturesPosition> selectOpenByUser(String userId);

    @Select("SELECT * FROM t_futures_position WHERE status = 0 ORDER BY id ASC")
    List<FuturesPosition> selectAllOpen();

    @Update("UPDATE t_futures_position SET amount = #{amount}, entry_price = #{entryPrice}, "
            + "leverage = #{leverage}, margin = #{margin} WHERE id = #{id}")
    int updateHolding(FuturesPosition position);

    @Select("SELECT * FROM t_futures_position WHERE id = #{id}")
    FuturesPosition selectById(Long id);

    @Update("UPDATE t_futures_position SET status = 1, amount = #{amount}, margin = #{margin}, "
            + "closed_at = NOW() WHERE id = #{id} AND status = 0")
    int close(FuturesPosition position);

    /** CAS 强平: 仅当 status=0 时更新,返回影响行数(0=已被其他线程强平) */
    @Update("UPDATE t_futures_position SET status = 2, amount = 0, margin = 0, "
            + "closed_at = NOW() WHERE id = #{id} AND status = 0")
    int casLiquidate(@Param("id") Long id);
}
