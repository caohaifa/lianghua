package com.aiquant.mapper;

import com.aiquant.model.PersonalSignal;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface PersonalSignalMapper {

    @Insert("INSERT INTO t_personal_signal (monitor_id, user_id, action, amount, ratio_pct, leverage, ok_count, skip_count, detail, created_at) "
            + "VALUES (#{monitorId}, #{userId}, #{action}, #{amount}, #{ratioPct}, #{leverage}, #{okCount}, #{skipCount}, #{detail}, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(PersonalSignal signal);

    @Select("SELECT * FROM t_personal_signal WHERE monitor_id = #{monitorId} ORDER BY id DESC LIMIT #{limit} OFFSET #{offset}")
    List<PersonalSignal> selectByMonitorPaged(@Param("monitorId") Long monitorId,
                                              @Param("limit") int limit,
                                              @Param("offset") int offset);

    @Select("SELECT COUNT(*) FROM t_personal_signal WHERE monitor_id = #{monitorId}")
    int countByMonitor(Long monitorId);
}
