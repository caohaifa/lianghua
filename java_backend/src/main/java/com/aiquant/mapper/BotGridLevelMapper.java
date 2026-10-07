package com.aiquant.mapper;

import com.aiquant.model.BotGridLevel;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;

@Mapper
public interface BotGridLevelMapper {

    @Insert("INSERT INTO t_bot_grid_level (monitor_id, grid_idx, trigger_price, side, amount, status, created_at, updated_at) "
            + "VALUES (#{monitorId}, #{gridIdx}, #{triggerPrice}, #{side}, #{amount}, #{status}, NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(BotGridLevel level);

    @Select("SELECT * FROM t_bot_grid_level WHERE monitor_id = #{monitorId} AND status = 'open' ORDER BY id ASC")
    List<BotGridLevel> selectOpenByMonitor(Long monitorId);

    @Select("SELECT COUNT(*) FROM t_bot_grid_level WHERE monitor_id = #{monitorId}")
    long countByMonitor(Long monitorId);

    @Update("UPDATE t_bot_grid_level SET status = #{status}, amount = #{amount}, updated_at = NOW() WHERE id = #{id}")
    int updateStatus(@Param("id") Long id, @Param("status") String status, @Param("amount") Double amount);
}
