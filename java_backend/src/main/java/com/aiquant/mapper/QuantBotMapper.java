package com.aiquant.mapper;

import com.aiquant.model.QuantBot;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;

@Mapper
public interface QuantBotMapper {

    @Insert("INSERT INTO t_quant_bot (bot_user_id, monitor_id, strategy_key, symbol, config_json, created_at) "
            + "VALUES (#{botUserId}, #{monitorId}, #{strategyKey}, #{symbol}, #{configJson}, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(QuantBot bot);

    @Select("SELECT * FROM t_quant_bot ORDER BY id ASC")
    List<QuantBot> selectAll();

    @Select("SELECT * FROM t_quant_bot WHERE monitor_id = #{monitorId}")
    QuantBot selectByMonitor(Long monitorId);

    @Select("SELECT * FROM t_quant_bot WHERE id = #{id}")
    QuantBot selectById(Long id);

    @Update("UPDATE t_quant_bot SET config_json = #{configJson} WHERE id = #{id}")
    int updateConfig(@Param("id") Long id, @Param("configJson") String configJson);
}
