package com.aiquant.mapper;

import com.aiquant.model.Alert;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface AlertMapper {

    @Insert("INSERT INTO t_alert (user_id, type, title, content, read_flag, created_at) "
            + "VALUES (#{userId}, #{type}, #{title}, #{content}, 0, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Alert alert);

    @Select("SELECT * FROM t_alert WHERE user_id = #{userId} ORDER BY id DESC LIMIT #{limit} OFFSET #{offset}")
    List<Alert> selectByUserPaged(@Param("userId") String userId,
                                  @Param("limit") int limit,
                                  @Param("offset") int offset);

    @Select("SELECT COUNT(*) FROM t_alert WHERE user_id = #{userId}")
    int countByUser(String userId);

    @Select("SELECT * FROM t_alert WHERE user_id = #{userId} ORDER BY id DESC LIMIT 50")
    List<Alert> selectByUser(String userId);

    @Select("SELECT COUNT(*) FROM t_alert WHERE user_id = #{userId} AND read_flag = 0")
    int countUnread(String userId);

    @Update("UPDATE t_alert SET read_flag = 1 WHERE user_id = #{userId} AND read_flag = 0")
    int markAllRead(String userId);

    /** 运营后台:全站最近告警 */
    @Select("SELECT * FROM t_alert ORDER BY id DESC LIMIT #{limit}")
    List<Alert> selectRecent(@Param("limit") int limit);
}
