package com.aiquant.mapper;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.Map;

/**
 * AI 量化首页聚合统计:累计/今日收益、运行策略数、胜率。
 */
@Mapper
public interface AiStatsMapper {

    @Select("SELECT COALESCE(SUM(pnl),0) FROM t_position "
            + "WHERE status = 1 AND user_id = #{userId}")
    double sumSpotRealized(String userId);

    @Select("SELECT COALESCE(SUM(pnl),0) FROM t_futures_order "
            + "WHERE action = 'close' AND user_id = #{userId}")
    double sumFuturesRealized(String userId);

    @Select("SELECT COUNT(*) AS total, "
            + "COALESCE(SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END),0) AS wins "
            + "FROM t_position WHERE status = 1 AND user_id = #{userId}")
    Map<String, Object> spotClosedStats(String userId);

    @Select("SELECT COUNT(*) AS total, "
            + "COALESCE(SUM(CASE WHEN pnl > 0 THEN 1 ELSE 0 END),0) AS wins "
            + "FROM t_futures_order WHERE action = 'close' AND user_id = #{userId}")
    Map<String, Object> futuresClosedStats(String userId);

    @Select("SELECT COUNT(*) FROM t_monitor WHERE status = 'running' AND user_id = #{userId}")
    int countRunningMonitors(String userId);

    @Select("SELECT COALESCE(SUM(pnl),0) FROM t_position "
            + "WHERE status = 1 AND user_id = #{userId} AND closed_at >= CURRENT_DATE")
    double sumSpotTodayPnl(String userId);

    @Select("SELECT COALESCE(SUM(pnl),0) FROM t_futures_order "
            + "WHERE action = 'close' AND user_id = #{userId} AND created_at >= CURRENT_DATE")
    double sumFuturesTodayPnl(String userId);
}
