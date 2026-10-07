package com.aiquant.mapper;

import com.aiquant.model.Banner;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface BannerMapper {

    @Insert("INSERT INTO t_banner (title, image_url, link_type, link_url, position, status, "
            + "start_time, end_time, creator, created_at, updated_at) "
            + "VALUES (#{title}, #{imageUrl}, #{linkType}, #{linkUrl}, #{position}, #{status}, "
            + "#{startTime}, #{endTime}, #{creator}, NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Banner banner);

    @Update("UPDATE t_banner SET title=#{title}, image_url=#{imageUrl}, link_type=#{linkType}, "
            + "link_url=#{linkUrl}, position=#{position}, status=#{status}, "
            + "start_time=#{startTime}, end_time=#{endTime}, updated_at=NOW() WHERE id=#{id}")
    int update(Banner banner);

    @Select("SELECT * FROM t_banner WHERE id = #{id}")
    Banner selectById(Long id);

    @Select("""
            <script>
            SELECT * FROM t_banner
            <where>
                <if test="status != null"> AND status = #{status} </if>
                <if test="title != null and title != ''"> AND title LIKE CONCAT('%', #{title}, '%') </if>
            </where>
            ORDER BY position DESC, id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<Banner> list(@Param("title") String title,
                      @Param("status") Integer status,
                      @Param("offset") int offset,
                      @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_banner
            <where>
                <if test="status != null"> AND status = #{status} </if>
                <if test="title != null and title != ''"> AND title LIKE CONCAT('%', #{title}, '%') </if>
            </where>
            </script>
            """)
    long count(@Param("title") String title, @Param("status") Integer status);

    @Update("UPDATE t_banner SET status=#{status}, updated_at=NOW() WHERE id=#{id}")
    int updateStatus(@Param("id") Long id, @Param("status") Integer status);
}
