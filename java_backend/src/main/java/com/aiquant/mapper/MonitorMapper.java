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

    @Select("SELECT * FROM t_monitor WHERE user_id = #{userId} ORDER BY id DESC")
    List<Monitor> selectByUser(String userId);

    @Select("SELECT COUNT(*) FROM t_monitor WHERE user_id = #{userId}")
    long countByUser(String userId);

    @Select("SELECT * FROM t_monitor WHERE status = 'running' ORDER BY id ASC")
    List<Monitor> selectRunning();

    @Update("UPDATE t_monitor SET signal = #{signal}, updated_at = NOW() WHERE id = #{id}")
    int updateSignal(@Param("id") Long id, @Param("signal") String signal);

    @Select("SELECT * FROM t_monitor WHERE id = #{id} AND user_id = #{userId}")
    Monitor selectByIdAndUser(@Param("id") Long id, @Param("userId") String userId);

    @Update("UPDATE t_monitor SET status = #{status}, updated_at = NOW() WHERE id = #{id} AND user_id = #{userId}")
    int updateStatus(@Param("id") Long id, @Param("userId") String userId, @Param("status") String status);

    @Delete("DELETE FROM t_monitor WHERE id = #{id} AND user_id = #{userId}")
    int deleteByIdAndUser(@Param("id") Long id, @Param("userId") String userId);
}
