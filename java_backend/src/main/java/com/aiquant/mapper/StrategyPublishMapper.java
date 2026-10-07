package com.aiquant.mapper;

import com.aiquant.model.StrategyPublish;
import org.apache.ibatis.annotations.*;

import java.util.List;
import java.util.Map;

@Mapper
public interface StrategyPublishMapper {

    String LEADER_NAME_SQL = "COALESCE(NULLIF(u.nickname, ''), "
            + "CONCAT(LEFT(u.phone,3), '****', RIGHT(u.phone,4))) AS leader_name";

    String PUBLISH_JOIN = "FROM t_strategy_publish p "
            + "LEFT JOIN t_user u ON u.user_id = p.leader_id ";

    @Insert("INSERT INTO t_strategy_publish (leader_id, monitor_id, title, description, strategy, symbol, status, created_at, updated_at) "
            + "VALUES (#{leaderId}, #{monitorId}, #{title}, #{description}, #{strategy}, #{symbol}, 'published', NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(StrategyPublish publish);

    @Insert("INSERT INTO t_strategy_publish (leader_id, monitor_id, title, description, strategy, symbol, status, is_bot, created_at, updated_at) "
            + "VALUES (#{leaderId}, #{monitorId}, #{title}, #{description}, #{strategy}, #{symbol}, 'published', 1, NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insertBotPublish(StrategyPublish publish);

    @Select("SELECT * FROM t_strategy_publish WHERE leader_id = #{leaderId} AND monitor_id = #{monitorId}")
    StrategyPublish selectByLeaderAndMonitor(@Param("leaderId") String leaderId, @Param("monitorId") Long monitorId);

    @Select("SELECT * FROM t_strategy_publish WHERE id = #{id}")
    StrategyPublish selectById(Long id);

    /** 重新提交:更新信息并保持直接发布生效 */
    @Update("UPDATE t_strategy_publish SET title = #{title}, description = #{description}, "
            + "status = 'published', updated_at = NOW() WHERE id = #{id}")
    int resubmit(@Param("id") Long id, @Param("title") String title, @Param("description") String description);

    @Update("UPDATE t_strategy_publish SET status = #{status}, updated_at = NOW() WHERE id = #{id}")
    int updateStatus(@Param("id") Long id, @Param("status") String status);

    @Select("SELECT p.*, " + LEADER_NAME_SQL + " " + PUBLISH_JOIN
            + "WHERE p.leader_id = #{leaderId} ORDER BY p.id DESC")
    List<StrategyPublish> selectByLeader(String leaderId);

    /** 策略广场:仅审核通过的发布 */
    @Select("SELECT p.*, " + LEADER_NAME_SQL + " " + PUBLISH_JOIN
            + "WHERE p.status = 'published' ORDER BY p.updated_at DESC")
    List<StrategyPublish> selectPublished();

    /** 后台审核列表(可按状态筛选) */
    @Select("<script>SELECT p.*, " + LEADER_NAME_SQL + " " + PUBLISH_JOIN
            + "<where><if test='status != null and status != \"\"'>p.status = #{status}</if></where> "
            + "ORDER BY p.id DESC LIMIT #{size} OFFSET #{offset}</script>")
    List<StrategyPublish> listForAdmin(@Param("status") String status,
                                       @Param("offset") int offset, @Param("size") int size);

    @Select("<script>SELECT COUNT(*) FROM t_strategy_publish p "
            + "<where><if test='status != null and status != \"\"'>p.status = #{status}</if></where></script>")
    long countForAdmin(@Param("status") String status);

    /** 各发布 active 跟单人数(publish_id → followers) */
    @Select("SELECT publish_id, COUNT(*) AS followers FROM t_strategy_follow "
            + "WHERE status = 'active' GROUP BY publish_id")
    List<Map<String, Object>> countFollowersGrouped();
}
