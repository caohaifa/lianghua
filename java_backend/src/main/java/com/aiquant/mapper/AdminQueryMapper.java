package com.aiquant.mapper;

import com.aiquant.vo.DashboardStatsVO;
import com.aiquant.vo.OrderAdminVO;
import com.aiquant.vo.PlanOrderAdminVO;
import com.aiquant.vo.PositionAdminVO;
import com.aiquant.vo.SettlementAdminVO;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.Map;

/**
 * 运营后台只读查询:交易/持仓/订阅/结算 + 数据看板。
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

    // ══════════════ 订阅订单 ══════════════

    @Select("""
            <script>
            SELECT id, user_id AS user_id, plan_level AS plan_level, amount, period,
                   status, created_at AS created_at
            FROM t_plan_order
            <where>
                <if test="keyword != null and keyword != ''"> AND user_id LIKE CONCAT('%', #{keyword}, '%') </if>
                <if test="status != null and status != ''"> AND status = #{status} </if>
            </where>
            ORDER BY id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<PlanOrderAdminVO> listPlanOrders(@Param("keyword") String keyword,
                                          @Param("status") String status,
                                          @Param("offset") int offset,
                                          @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_plan_order
            <where>
                <if test="keyword != null and keyword != ''"> AND user_id LIKE CONCAT('%', #{keyword}, '%') </if>
                <if test="status != null and status != ''"> AND status = #{status} </if>
            </where>
            </script>
            """)
    long countPlanOrders(@Param("keyword") String keyword, @Param("status") String status);

    // ══════════════ 分成结算 ══════════════

    @Select("""
            <script>
            SELECT id, user_id AS user_id, profit_amount AS profit_amount, share_ratio AS share_ratio,
                   share_amount AS share_amount, settled_at AS settled_at
            FROM t_profit_settlement
            <where>
                <if test="keyword != null and keyword != ''"> AND user_id LIKE CONCAT('%', #{keyword}, '%') </if>
            </where>
            ORDER BY id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<SettlementAdminVO> listSettlements(@Param("keyword") String keyword,
                                            @Param("offset") int offset,
                                            @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_profit_settlement
            <if test="keyword != null and keyword != ''">
                WHERE user_id LIKE CONCAT('%', #{keyword}, '%')
            </if>
            </script>
            """)
    long countSettlements(@Param("keyword") String keyword);

    // ══════════════ 数据看板 ══════════════

    @Select("""
            SELECT
              (SELECT COUNT(*) FROM t_user) AS total_users,
              (SELECT COUNT(*) FROM t_user WHERE created_at >= CURRENT_DATE) AS today_new_users,
              (SELECT COUNT(*) FROM t_user WHERE status = 1) AS frozen_users,
              (SELECT COUNT(DISTINCT user_id) FROM t_user_device WHERE last_login >= CURRENT_DATE) AS dau,
              (SELECT COALESCE(SUM(amount * COALESCE(price, 0)), 0) FROM t_order WHERE status = 'filled') AS trade_volume,
              (SELECT COUNT(*) FROM t_order) AS order_count,
              (SELECT COALESCE(SUM(share_amount), 0) FROM t_profit_settlement) AS settlement_income,
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
}
