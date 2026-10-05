package com.aiquant.mapper;

import com.aiquant.model.Strategy;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface StrategyMapper {

    @Insert("INSERT INTO t_strategy (strategy_id, name, description, exchange, symbols, status, " +
            "risk_level, gray_percent, creator, created_at, updated_at) " +
            "VALUES (#{strategyId}, #{name}, #{description}, #{exchange}, #{symbols}, #{status}, " +
            "#{riskLevel}, #{grayPercent}, #{creator}, NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Strategy strategy);

    @Update("UPDATE t_strategy SET name=#{name}, description=#{description}, exchange=#{exchange}, " +
            "symbols=#{symbols}, risk_level=#{riskLevel}, updated_at=NOW() WHERE id=#{id}")
    int update(Strategy strategy);

    @Update("UPDATE t_strategy SET status=#{status}, gray_percent=#{grayPercent}, updated_at=NOW() WHERE id=#{id}")
    int updateStatus(@Param("id") Long id,
                     @Param("status") String status,
                     @Param("grayPercent") int grayPercent);

    @Select("SELECT * FROM t_strategy WHERE id = #{id}")
    Strategy selectById(Long id);

    @Select("SELECT * FROM t_strategy WHERE strategy_id = #{strategyId}")
    Strategy selectByStrategyId(String strategyId);

    @Select("""
            <script>
            SELECT * FROM t_strategy
            <where>
                <if test="status != null and status != ''"> AND status = #{status} </if>
                <if test="name != null and name != ''"> AND name LIKE CONCAT('%', #{name}, '%') </if>
            </where>
            ORDER BY id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<Strategy> list(@Param("name") String name,
                        @Param("status") String status,
                        @Param("offset") int offset,
                        @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_strategy
            <where>
                <if test="status != null and status != ''"> AND status = #{status} </if>
                <if test="name != null and name != ''"> AND name LIKE CONCAT('%', #{name}, '%') </if>
            </where>
            </script>
            """)
    long count(@Param("name") String name, @Param("status") String status);
}
