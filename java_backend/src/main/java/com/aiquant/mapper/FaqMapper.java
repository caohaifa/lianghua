package com.aiquant.mapper;

import com.aiquant.model.Faq;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface FaqMapper {

    @Insert("INSERT INTO t_faq (category, question, answer, sort_order, status, creator, created_at, updated_at) "
            + "VALUES (#{category}, #{question}, #{answer}, #{sortOrder}, #{status}, #{creator}, NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(Faq faq);

    @Update("UPDATE t_faq SET category=#{category}, question=#{question}, answer=#{answer}, "
            + "sort_order=#{sortOrder}, status=#{status}, updated_at=NOW() WHERE id=#{id}")
    int update(Faq faq);

    @Select("SELECT * FROM t_faq WHERE id = #{id}")
    Faq selectById(Long id);

    @Select("""
            <script>
            SELECT * FROM t_faq
            <where>
                <if test="category != null and category != ''"> AND category = #{category} </if>
                <if test="status != null"> AND status = #{status} </if>
                <if test="keyword != null and keyword != ''">
                    AND (question LIKE CONCAT('%', #{keyword}, '%') OR answer LIKE CONCAT('%', #{keyword}, '%'))
                </if>
            </where>
            ORDER BY sort_order ASC, id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<Faq> list(@Param("category") String category,
                   @Param("keyword") String keyword,
                   @Param("status") Integer status,
                   @Param("offset") int offset,
                   @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_faq
            <where>
                <if test="category != null and category != ''"> AND category = #{category} </if>
                <if test="status != null"> AND status = #{status} </if>
                <if test="keyword != null and keyword != ''">
                    AND (question LIKE CONCAT('%', #{keyword}, '%') OR answer LIKE CONCAT('%', #{keyword}, '%'))
                </if>
            </where>
            </script>
            """)
    long count(@Param("category") String category,
               @Param("keyword") String keyword,
               @Param("status") Integer status);

    @Select("SELECT DISTINCT category FROM t_faq ORDER BY category")
    List<String> selectCategories();
}
