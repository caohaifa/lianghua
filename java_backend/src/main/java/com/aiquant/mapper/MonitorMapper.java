package com.aiquant.mapper;

import com.aiquant.model.Monitor;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface MonitorMapper {

    @Insert("INSERT INTO t_monitor (user_id, symbol, strategy, status, signal, created_at, updated_at) "
            +
            "VALUES (#{userId}, #{symbol}, #{strategy}, 'running', '等待信号', NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Monitor monitor);

    @Insert("INSERT INTO t_monitor (user_id, symbol, strategy, status, signal, source, created_at, updated_at) "
            +
            "VALUES (#{userId}, #{symbol}, #{strategy}, 'running', '等待信号', 'bot', NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insertBot(Monitor monitor);

    @Select("SELECT * FROM t_monitor WHERE user_id = #{userId} ORDER BY id DESC")
    List<Monitor> selectByUser(String userId);

    @Select("SELECT COUNT(*) FROM t_monitor WHERE user_id = #{userId}")
    long countByUser(String userId);

    /** 用户监控(机器人监控由独立引擎执行) */
    @Select("SELECT * FROM t_monitor WHERE status = 'running' "
            + "AND (source = 'user' OR source IS NULL) ORDER BY id ASC")
    List<Monitor> selectRunning();

    /** 机器人监控 */
    @Select("SELECT m.* FROM t_monitor m INNER JOIN t_quant_bot b ON b.monitor_id = m.id "
            + "WHERE m.status = 'running' AND m.source = 'bot' ORDER BY m.id ASC")
    List<Monitor> selectRunningBots();

    @Update("UPDATE t_monitor SET signal = #{signal}, updated_at = NOW() WHERE id = #{id}")
    int updateSignal(@Param("id") Long id, @Param("signal") String signal);

    @Select("SELECT * FROM t_monitor WHERE id = #{id} AND user_id = #{userId}")
    Monitor selectByIdAndUser(@Param("id") Long id, @Param("userId") String userId);

    @Update("UPDATE t_monitor SET status = #{status}, updated_at = NOW() WHERE id = #{id} AND user_id = #{userId}")
    int updateStatus(@Param("id") Long id, @Param("userId") String userId, @Param("status") String status);

    @Update("UPDATE t_monitor SET params = #{params}, updated_at = NOW() WHERE id = #{id} AND user_id = #{userId}")
    int updateParams(@Param("id") Long id, @Param("userId") String userId, @Param("params") String params);

    @Delete("DELETE FROM t_monitor WHERE id = #{id} AND user_id = #{userId}")
    int deleteByIdAndUser(@Param("id") Long id, @Param("userId") String userId);

    // ══════════════ 后台运营(不限用户) ══════════════

    @Select("SELECT * FROM t_monitor WHERE id = #{id}")
    Monitor selectByIdAny(@Param("id") Long id);

    @Update("UPDATE t_monitor SET status = #{status}, updated_at = NOW() WHERE id = #{id}")
    int updateStatusAny(@Param("id") Long id, @Param("status") String status);
}
