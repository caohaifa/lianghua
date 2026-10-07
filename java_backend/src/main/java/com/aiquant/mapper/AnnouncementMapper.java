package com.aiquant.mapper;

import com.aiquant.model.Announcement;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface AnnouncementMapper {

    @Insert("INSERT INTO t_announcement (title, content, status, publisher_id, published_at, category, pinned, created_at, updated_at) " +
            "VALUES (#{title}, #{content}, #{status}, #{publisherId}, #{publishedAt}, #{category}, #{pinned}, NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Announcement announcement);

    @Update("UPDATE t_announcement SET title=#{title}, content=#{content}, status=#{status}, " +
            "published_at=#{publishedAt}, category=#{category}, pinned=#{pinned}, updated_at=NOW() WHERE id=#{id}")
    int update(Announcement announcement);

    @Select("SELECT * FROM t_announcement WHERE id = #{id}")
    Announcement selectById(Long id);

    @Select("""
            <script>
            SELECT * FROM t_announcement
            <where>
                <if test="status != null"> AND status = #{status} </if>
                <if test="title != null and title != ''"> AND title LIKE CONCAT('%', #{title}, '%') </if>
            </where>
            ORDER BY pinned DESC, id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<Announcement> list(@Param("title") String title,
                            @Param("status") Integer status,
                            @Param("offset") int offset,
                            @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_announcement
            <where>
                <if test="status != null"> AND status = #{status} </if>
                <if test="title != null and title != ''"> AND title LIKE CONCAT('%', #{title}, '%') </if>
            </where>
            </script>
            """)
    long count(@Param("title") String title, @Param("status") Integer status);
}
