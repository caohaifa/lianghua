package com.aiquant.mapper;

import com.aiquant.model.SignalLog;
import org.apache.ibatis.annotations.*;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface SignalLogMapper {

    @Insert("INSERT INTO t_signal_log (monitor_id, user_id, action, signal, created_at) "
            + "VALUES (#{monitorId}, #{userId}, #{action}, #{signal}, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(SignalLog log);

    /** 某监控最近的信号历史(倒序) */
    @Select("SELECT * FROM t_signal_log WHERE monitor_id = #{monitorId} ORDER BY id DESC LIMIT #{limit}")
    List<SignalLog> selectRecent(@Param("monitorId") Long monitorId, @Param("limit") int limit);

    /** 全局清理 cutoff 之前的历史(定时维护任务用) */
    @Delete("DELETE FROM t_signal_log WHERE created_at < #{cutoff}")
    int deleteAllBefore(@Param("cutoff") LocalDateTime cutoff);
}
