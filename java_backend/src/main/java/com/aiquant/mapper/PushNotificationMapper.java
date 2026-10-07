package com.aiquant.mapper;

import com.aiquant.model.PushNotification;
import org.apache.ibatis.annotations.*;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface PushNotificationMapper {

    @Insert("INSERT INTO t_push_notification (title, content, target_type, target_value, "
            + "status, scheduled_at, creator, created_at, updated_at) "
            + "VALUES (#{title}, #{content}, #{targetType}, #{targetValue}, "
            + "#{status}, #{scheduledAt}, #{creator}, NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(PushNotification notification);

    @Update("UPDATE t_push_notification SET title=#{title}, content=#{content}, "
            + "target_type=#{targetType}, target_value=#{targetValue}, "
            + "status=#{status}, scheduled_at=#{scheduledAt}, updated_at=NOW() WHERE id=#{id}")
    int update(PushNotification notification);

    @Select("SELECT * FROM t_push_notification WHERE id = #{id}")
    PushNotification selectById(Long id);

    @Select("""
            <script>
            SELECT * FROM t_push_notification
            <where>
                <if test="status != null"> AND status = #{status} </if>
                <if test="keyword != null and keyword != ''">
                    AND (title LIKE CONCAT('%', #{keyword}, '%') OR content LIKE CONCAT('%', #{keyword}, '%'))
                </if>
            </where>
            ORDER BY id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<PushNotification> list(@Param("keyword") String keyword,
                                @Param("status") Integer status,
                                @Param("offset") int offset,
                                @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_push_notification
            <where>
                <if test="status != null"> AND status = #{status} </if>
                <if test="keyword != null and keyword != ''">
                    AND (title LIKE CONCAT('%', #{keyword}, '%') OR content LIKE CONCAT('%', #{keyword}, '%'))
                </if>
            </where>
            </script>
            """)
    long count(@Param("keyword") String keyword, @Param("status") Integer status);

    @Update("UPDATE t_push_notification SET status=#{status}, sent_at=#{sentAt}, "
            + "sent_count=#{sentCount}, updated_at=NOW() WHERE id=#{id}")
    int markSent(@Param("id") Long id, @Param("status") Integer status,
                 @Param("sentAt") LocalDateTime sentAt, @Param("sentCount") int sentCount);
}
