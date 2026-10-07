package com.aiquant.mapper;

import com.aiquant.vo.DashboardStatsVO;
import com.aiquant.vo.OrderAdminVO;
import com.aiquant.vo.PositionAdminVO;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.Map;

/**
 * 运营后台只读查询:交易/持仓 + 数据看板。
 * 统一返回 VO,SQL 用 snake_case 别名,由 mapUnderscoreToCamelCase 映射到驼峰字段,
 * 避免 H2/MySQL 对列别名大小写处理不一致导致前端取不到值。
 */
@Mapper
public interface AdminQueryMapper {

    // ══════════════ 委托订单 ══════════════

    @Select("""
            <script>
            SELECT id, user_id AS user_id, order_id AS order_id, symbol,
                   CASE WHEN symbol LIKE '%/%' THEN 'USDT' ELSE 'CNY' END AS currency,
                   side,
                   order_type AS order_type, price, amount, filled_amount AS filled_amount,
                   status, strategy_name AS strategy_name, created_at AS created_at
            FROM t_order
            <where>
                <if test="keyword != null and keyword != ''">
                    AND (symbol LIKE CONCAT('%', #{keyword}, '%')
                         OR order_id LIKE CONCAT('%', #{keyword}, '%')
                         OR user_id LIKE CONCAT('%', #{keyword}, '%'))
                </if>
                <if test="status != null and status != ''"> AND status = #{status} </if>
            </where>
            ORDER BY id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<OrderAdminVO> listOrders(@Param("keyword") String keyword,
                                  @Param("status") String status,
                                  @Param("offset") int offset,
                                  @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_order
            <where>
                <if test="keyword != null and keyword != ''">
                    AND (symbol LIKE CONCAT('%', #{keyword}, '%')
                         OR order_id LIKE CONCAT('%', #{keyword}, '%')
                         OR user_id LIKE CONCAT('%', #{keyword}, '%'))
                </if>
                <if test="status != null and status != ''"> AND status = #{status} </if>
            </where>
            </script>
            """)
    long countOrders(@Param("keyword") String keyword, @Param("status") String status);

    // ══════════════ 持仓 ══════════════

    @Select("""
            <script>
            SELECT id, user_id AS user_id, symbol,
                   CASE WHEN symbol LIKE '%/%' THEN 'USDT' ELSE 'CNY' END AS currency,
                   side, amount, entry_price AS entry_price,
                   current_price AS current_price, pnl, pnl_pct AS pnl_pct,
                   strategy_name AS strategy_name, status, opened_at AS opened_at, closed_at AS closed_at
            FROM t_position
            <where>
                <if test="keyword != null and keyword != ''">
                    AND (symbol LIKE CONCAT('%', #{keyword}, '%') OR user_id LIKE CONCAT('%', #{keyword}, '%'))
                </if>
                <if test="status != null"> AND status = #{status} </if>
            </where>
            ORDER BY id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<PositionAdminVO> listPositions(@Param("keyword") String keyword,
                                        @Param("status") Integer status,
                                        @Param("offset") int offset,
                                        @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_position
            <where>
                <if test="keyword != null and keyword != ''">
                    AND (symbol LIKE CONCAT('%', #{keyword}, '%') OR user_id LIKE CONCAT('%', #{keyword}, '%'))
                </if>
                <if test="status != null"> AND status = #{status} </if>
            </where>
            </script>
            """)
    long countPositions(@Param("keyword") String keyword, @Param("status") Integer status);

    // ══════════════ 钱包流水 ══════════════

    @Select("""
            <script>
            SELECT id, user_id AS user_id, currency, type, amount, channel, address, status, created_at AS created_at
            FROM t_wallet_transaction
            <where>
                <if test="keyword != null and keyword != ''"> AND user_id LIKE CONCAT('%', #{keyword}, '%') </if>
                <if test="type != null and type != ''"> AND type = #{type} </if>
            </where>
            ORDER BY id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<Map<String, Object>> listWalletTransactions(@Param("keyword") String keyword,
                                                     @Param("type") String type,
                                                     @Param("offset") int offset,
                                                     @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_wallet_transaction
            <where>
                <if test="keyword != null and keyword != ''"> AND user_id LIKE CONCAT('%', #{keyword}, '%') </if>
                <if test="type != null and type != ''"> AND type = #{type} </if>
            </where>
            </script>
            """)
    long countWalletTransactions(@Param("keyword") String keyword, @Param("type") String type);

    // ══════════════ 数据看板 ══════════════

    @Select("""
            SELECT
              (SELECT COUNT(*) FROM t_user) AS total_users,
              (SELECT COUNT(*) FROM t_user WHERE created_at >= CURRENT_DATE) AS today_new_users,
              (SELECT COUNT(*) FROM t_user WHERE status = 1) AS frozen_users,
              (SELECT COUNT(DISTINCT user_id) FROM t_user_device WHERE last_login >= CURRENT_DATE) AS dau,
              (SELECT COALESCE(SUM(amount * COALESCE(price, 0)), 0) FROM t_order WHERE status = 'filled') AS trade_volume,
              (SELECT COUNT(*) FROM t_order) AS order_count,
              (SELECT COUNT(*) FROM t_strategy WHERE status = 'online') AS online_strategies,
              (SELECT COUNT(*) FROM t_position WHERE status = 0) AS open_positions
            """)
    DashboardStatsVO dashboardStats();

    /** 近 7 天每日新增用户(按创建日期聚合);起始日期由 Service 计算以兼容 H2/MySQL */
    @Select("""
            SELECT CAST(created_at AS DATE) AS date, COUNT(*) AS count
            FROM t_user
            WHERE created_at >= #{since}
            GROUP BY CAST(created_at AS DATE)
            ORDER BY date
            """)
    List<Map<String, Object>> userGrowth7d(@Param("since") java.time.LocalDateTime since);

    /** 用户风险等级分布 */
    @Select("""
            SELECT COALESCE(risk_level, '未测评') AS level, COUNT(*) AS count
            FROM t_user
            GROUP BY risk_level
            """)
    List<Map<String, Object>> riskDistribution();

    /** 近 7 天每日成交额(按订单成交日期聚合) */
    @Select("""
            SELECT CAST(created_at AS DATE) AS date,
                   COALESCE(SUM(amount * COALESCE(price, 0)), 0) AS volume
            FROM t_order
            WHERE status = 'filled' AND created_at >= #{since}
            GROUP BY CAST(created_at AS DATE)
            ORDER BY date
            """)
    List<Map<String, Object>> tradeVolume7d(@Param("since") java.time.LocalDateTime since);

    // ══════════════ 后台-返佣/团队管理 ══════════════

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_referral_reward
            <where>
                <if test="referrer != null and referrer != ''"> AND referrer_id LIKE CONCAT('%', #{referrer}, '%') </if>
                <if test="currency != null and currency != ''"> AND currency = #{currency} </if>
            </where>
            </script>
            """)
    long countAdminRewards(@Param("referrer") String referrer, @Param("currency") String currency);

    @Select("""
            <script>
            SELECT id, referrer_id AS referrerid, trader_id AS traderid, order_id AS orderid,
                   symbol, currency, volume, reward, created_at AS createdat
            FROM t_referral_reward
            <where>
                <if test="referrer != null and referrer != ''"> AND referrer_id LIKE CONCAT('%', #{referrer}, '%') </if>
                <if test="currency != null and currency != ''"> AND currency = #{currency} </if>
            </where>
            ORDER BY id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<Map<String, Object>> selectAdminRewards(@Param("referrer") String referrer,
                                                 @Param("currency") String currency,
                                                 @Param("size") int size,
                                                 @Param("offset") int offset);

    /** 推荐人团队聚合(团队人数=受邀数, 活跃=成交去重, 流水/返佣分币种) */
    @Select("""
            SELECT r.referrer_id AS referrerid,
                   (SELECT COUNT(*) FROM t_user u WHERE u.invited_by = r.referrer_id) AS teamcount,
                   COUNT(DISTINCT r.trader_id) AS activecount,
                   SUM(CASE WHEN r.currency = 'USDT' THEN r.volume ELSE 0 END) AS volusdt,
                   SUM(CASE WHEN r.currency = 'CNY' THEN r.volume ELSE 0 END) AS volcny,
                   SUM(CASE WHEN r.currency = 'USDT' THEN r.reward ELSE 0 END) AS rewardusdt,
                   SUM(CASE WHEN r.currency = 'CNY' THEN r.reward ELSE 0 END) AS rewardcny
            FROM t_referral_reward r
            GROUP BY r.referrer_id
            ORDER BY (SUM(CASE WHEN r.currency = 'USDT' THEN r.reward ELSE 0 END)
                    + SUM(CASE WHEN r.currency = 'CNY' THEN r.reward ELSE 0 END)) DESC
            """)
    List<Map<String, Object>> selectAdminTeams();

    // ══════════════ 后台-监控总览 ══════════════

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_monitor
            <where>
                <if test="strategy != null and strategy != ''"> AND strategy = #{strategy} </if>
                <if test="status != null and status != ''"> AND status = #{status} </if>
                <if test="source != null and source != ''"> AND source = #{source} </if>
            </where>
            </script>
            """)
    long countAdminMonitors(@Param("strategy") String strategy,
                            @Param("status") String status,
                            @Param("source") String source);

    @Select("""
            <script>
            SELECT m.id, m.user_id AS userid, m.symbol, m.strategy, m.status, m.signal,
                   m.source, m.created_at AS createdat,
                   (SELECT COUNT(*) FROM t_personal_signal s WHERE s.monitor_id = m.id) AS signalcount,
                   (SELECT COUNT(*) FROM t_strategy_follow f WHERE f.monitor_id = m.id) AS followcount
            FROM t_monitor m
            <where>
                <if test="strategy != null and strategy != ''"> AND m.strategy = #{strategy} </if>
                <if test="status != null and status != ''"> AND m.status = #{status} </if>
                <if test="source != null and source != ''"> AND m.source = #{source} </if>
            </where>
            ORDER BY m.id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<Map<String, Object>> selectAdminMonitors(@Param("strategy") String strategy,
                                                  @Param("status") String status,
                                                  @Param("source") String source,
                                                  @Param("size") int size,
                                                  @Param("offset") int offset);

    /** 监控策略分布(下拉筛选用) */
    @Select("SELECT DISTINCT strategy FROM t_monitor ORDER BY strategy")
    List<String> selectMonitorStrategies();
}
