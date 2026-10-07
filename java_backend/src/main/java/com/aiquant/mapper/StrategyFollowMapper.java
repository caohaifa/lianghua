package com.aiquant.mapper;

import com.aiquant.model.StrategyFollow;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface StrategyFollowMapper {

    @Insert("INSERT INTO t_strategy_follow (user_id, publish_id, leader_id, monitor_id, ratio, mode, fixed_multiplier, status, created_at, updated_at) "
            + "VALUES (#{userId}, #{publishId}, #{leaderId}, #{monitorId}, #{ratio}, #{mode}, #{fixedMultiplier}, 'active', NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(StrategyFollow follow);

    @Select("SELECT * FROM t_strategy_follow WHERE user_id = #{userId} AND publish_id = #{publishId}")
    StrategyFollow selectByUserAndPublish(@Param("userId") String userId, @Param("publishId") Long publishId);

    @Select("SELECT * FROM t_strategy_follow WHERE id = #{id} AND user_id = #{userId}")
    StrategyFollow selectByIdAndUser(@Param("id") Long id, @Param("userId") String userId);

    /** 重复跟单 = 更新比例/模式并重新激活 */
    @Update("UPDATE t_strategy_follow SET ratio = #{ratio}, mode = #{mode}, fixed_multiplier = #{fixedMultiplier}, "
            + "status = 'active', updated_at = NOW() WHERE id = #{id}")
    int updateFollow(@Param("id") Long id, @Param("ratio") Integer ratio,
                     @Param("mode") String mode, @Param("fixedMultiplier") Double fixedMultiplier);

    /** follower 暂停/恢复自己的跟单(active/paused) */
    @Update("UPDATE t_strategy_follow SET status = #{status}, updated_at = NOW() WHERE id = #{id} AND user_id = #{userId}")
    int updateStatusByIdAndUser(@Param("id") Long id, @Param("userId") String userId, @Param("status") String status);

    @Select("SELECT * FROM t_strategy_follow WHERE monitor_id = #{monitorId} AND status = 'active'")
    List<StrategyFollow> selectActiveByMonitor(Long monitorId);

    /** 我的跟单列表:联发布表取展示字段,附复制笔数与已实现盈亏汇总 */
    @Select("SELECT f.*, p.title, p.strategy, p.symbol, p.status AS publish_status, "
            + "COALESCE(NULLIF(u.nickname, ''), CONCAT(LEFT(u.phone,3), '****', RIGHT(u.phone,4))) AS leader_name, "
            + "(SELECT COUNT(*) FROM t_copy_trade ct WHERE ct.follow_id = f.id) AS trade_count, "
            + "(SELECT COALESCE(SUM(ct.pnl), 0) FROM t_copy_trade ct WHERE ct.follow_id = f.id) AS total_pnl "
            + "FROM t_strategy_follow f "
            + "LEFT JOIN t_strategy_publish p ON p.id = f.publish_id "
            + "LEFT JOIN t_user u ON u.user_id = f.leader_id "
            + "WHERE f.user_id = #{userId} ORDER BY f.id DESC")
    List<StrategyFollow> selectByUser(String userId);

    @Update("UPDATE t_strategy_follow SET status = 'stopped', updated_at = NOW() WHERE id = #{id} AND user_id = #{userId}")
    int stopByIdAndUser(@Param("id") Long id, @Param("userId") String userId);

    /** 下架/删监控时批量停止跟单 */
    @Update("UPDATE t_strategy_follow SET status = 'stopped', updated_at = NOW() WHERE publish_id = #{publishId} AND status = 'active'")
    int stopByPublishId(Long publishId);
}
